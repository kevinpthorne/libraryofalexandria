inputs @ { ... }:
let
    # Manual registration
    # clusters = [
    #     "k"
    # ];
    # Auto registration -- assumes any directory is a cluster definition
    folderContents = builtins.readDir ./.;
    folderDirectories = inputs.nixpkgs.lib.filterAttrs (path: type: type == "directory") folderContents;
    # TODO validate that all nix-modules are valid cluster definitions
    clusters = inputs.nixpkgs.lib.mapAttrsToList (path: type: path) folderDirectories;

    clusterConfigsSet = builtins.listToAttrs (
        builtins.map (clusterName: {
            name = clusterName;
            value = import ./${clusterName} inputs;
        }) clusters
    );  # { k = { name = "k"; ... }; t = {...}; ... }
in
{}