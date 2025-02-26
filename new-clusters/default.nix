inputs @ { ... }:
let
    folderContents = builtins.readDir ./.;
    folderDirectories = inputs.nixpkgs.lib.filterAttrs (path: type: type == "directory") folderContents;
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
    
    nixosConfigurations = collectAll (cluster: cluster.nixosConfigurations);
    packages = collectAll (cluster: cluster.);
in
{
    inherit nixosConfigurations;
    # inherit packages;
}