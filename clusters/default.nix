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


    # foreach cluster
    #   for i in range 0, masters.count:
    #     yield nixosSystem { ... }
    #   for i in range 0, workers.count:
    #     yield nixosSystem { ... }
    range = n: builtins.genList (x: x) n;
    allNixosConfigsFor = configSet:
        builtins.listToAttrs (
            builtins.foldl' (acc: clusterName:
            let
                clusterConfig = configSet.${clusterName};
                masterConfigs = builtins.map (i: {
                    name = "master${toString i}-${clusterName}";
                    value = inputs.nixpkgs.lib.nixosSystem {
                        system = clusterConfig.system;
                        modules = clusterConfig.masters.modules i;
                        extraModules = [ inputs.colmena.nixosModules.deploymentOptions ];
                    };
                }) (range (clusterConfig.masters.count));
                workerConfigs = builtins.map (i: {
                    name = "worker${toString i}-${clusterName}";
                    value = inputs.nixpkgs.lib.nixosSystem {
                        system = clusterConfig.system;
                        modules = clusterConfig.workers.modules i;
                        extraModules = [ inputs.colmena.nixosModules.deploymentOptions ];
                    };
                }) (range (clusterConfig.workers.count));
            in acc ++ masterConfigs ++ workerConfigs) [] (builtins.attrNames configSet)
        );
in
    allNixosConfigsFor clusterConfigsSet