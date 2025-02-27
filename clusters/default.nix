inputs @ { eachArch, ... }:
let
    range = n: builtins.genList (x: x) n;
    importIfExists = import ../lib/import-if-exists.nix;
    pathIfExists = import ../lib/path-if-exists;
    deepMerge = import ../lib/deep-merge.nix inputs.nixpkgs.lib;
    #
    folderContents = builtins.readDir ./.;
    folderDirectories = inputs.nixpkgs.lib.filterAttrs (
        path: type: type == "directory" && !(inputs.nixpkgs.lib.strings.hasPrefix path "_")
    ) folderContents;
    clusterFolders = inputs.nixpkgs.lib.mapAttrsToList (path: type: path) folderDirectories;
    clusters = builtins.listToAttrs (
        builtins.map (clusterName: let
            clusterModule = inputs.nixpkgs.lib.evalModules {
                modules = [
                    (import ./cluster-module.nix)
                    (import ./${clusterName})
                ];
                specialArgs = {
                    inherit inputs;
                    lib2 = {
                        inherit range;
                        inherit importIfExists;
                        inherit pathIfExists;
                        inherit deepMerge;
                        inherit eachArch;
                    };
                };
            };
        in {
            name = clusterName;
            value = clusterModule.config;
        }) clusterFolders
    );  # { k = { libraryofalexandria.cluster.name = "k"; ... }; t = {...}; ... }

    collectAll = getter: builtins.foldl' (acc: clusterName:
       acc // (getter (clusters.${clusterName}))
    ) {} (builtins.attrNames clusters);
    mergeAll = getter: builtins.foldl' (acc: clusterName:
        deepMerge [ acc (getter (clusters.${clusterName})) ]
    ) {} (builtins.attrNames clusters);
    
    nixosConfigurations = collectAll (cluster: cluster.nixosConfigurations);
    packages = mergeAll (cluster: cluster.packages);
in
{
    inherit nixosConfigurations;
    inherit packages;
}