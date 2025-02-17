inputs @ { ... }:
let
    range = n: builtins.genList (x: x) n;
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
        builtins.map (clusterName: let
            config = import ./${clusterName} inputs;
        in {
            name = clusterName;
            value = config;
        }) clusters
    );  # { k = { name = "k"; ... }; t = {...}; ... }
    getSystem = clusterName: 
        let
            clusterConfig = clusterConfigsSet.${clusterName};
        in 
        nodeType: nodeId: {
            "${nodeType}${toString nodeId}-${clusterName}" = inputs.nixpkgs.lib.nixosSystem {
                system = clusterConfig.system;  # TODO some overrides should be available here, no?
                modules = clusterConfig."${nodeType}s".modules nodeId;
                extraModules = [ inputs.colmena.nixosModules.deploymentOptions ];
            };
        };
    getMasterSystem = clusterName: nodeId: getSystem clusterName "master" nodeId;
    getWorkerSystem = clusterName: nodeId: getSystem clusterName "worker" nodeId;

    # foreach cluster
    #   for i in range 0, masters.count:
    #     yield nixosSystem { ... }
    #   for i in range 0, workers.count:
    #     yield nixosSystem { ... }
    nixosConfigurations = builtins.foldl' (acc: clusterName:
        let
            clusterConfig = clusterConfigsSet.${clusterName};
            masterSystems = builtins.foldl' (acc: i: acc // (getMasterSystem clusterName i)) {} (range clusterConfig.masters.count);
            workerSystems = builtins.foldl' (acc: i: acc // (getWorkerSystem clusterName i)) {} (range clusterConfig.workers.count);
        in
            acc // masterSystems // workerSystems
    ) {} (builtins.attrNames clusterConfigsSet);

    # allSystemsBuilder = clusterName: inputs.nixpkgs.stdenv.mkDerivation {
    #     name = "build-all-${clusterName}";
        
    #     buildPhase = ''
    #         mkdir -p $out/sd-images
    #         ${builtins.concatStringsSep "\n" (builtins.mapAttrs (name: v: ''
    #             echo "Building ${name}..."
    #             ${v.system}/bin/nixos build .#nixosConfigurations.${name}.config.system.build.sdImage
    #         '') systems)}

    #         echo "All systems built!"
    #     '';
    # };

    packages = {
        aarch64-linux = {};
    };
in
{
    inherit nixosConfigurations;
}