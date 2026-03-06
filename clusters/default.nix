inputs @ { eachArch, localPkgs, ... }:
let
    lib2Pre = import ../lib // { inherit eachArch; };
    lib2 = lib2Pre // { deepMerge = lib2Pre.deepMerge inputs.nixpkgs.lib; };
    #
    folderContents = builtins.readDir ./.;
    folderDirectories = inputs.nixpkgs.lib.filterAttrs (
        path: type: (type == "directory") && !(inputs.nixpkgs.lib.strings.hasPrefix "_" path)
    ) folderContents;
    clusterFolders = inputs.nixpkgs.lib.mapAttrsToList (path: type: path) folderDirectories;
    clusters = builtins.listToAttrs (
        builtins.map (clusterName: let
            clusterModule = inputs.nixpkgs.lib.evalModules {
                modules = [
                    ./cluster-module.nix
                    ./${clusterName}
                ];
                specialArgs = {
                    inherit inputs;
                    inherit lib2;
                    inherit localPkgs;
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
        lib2.deepMerge [ acc (getter (clusters.${clusterName})) ]
    ) {} (builtins.attrNames clusters);
    
    nixosConfigurations = collectAll (cluster: cluster.nixosConfigurations);
    colmena = collectAll (cluster: cluster.colmena);
    packages = mergeAll (cluster: cluster.packages);
in
{
    by_name = clusters;
    inherit nixosConfigurations;
    inherit colmena;
    inherit packages;
}