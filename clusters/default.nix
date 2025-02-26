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
    getNixosSystemName = clusterName: nodeType: nodeId: "${nodeType}${toString nodeId}-${clusterName}";
    getNixosSystem = clusterName: 
        let
            clusterConfig = clusterConfigsSet.${clusterName};
        in 
        nodeType: nodeId: {
            "${(getNixosSystemName clusterName nodeType nodeId)}" = inputs.nixpkgs.lib.nixosSystem {
                modules = clusterConfig."${nodeType}s".modules nodeId;
                specialArgs = {
                    inherit inputs;
                };
                extraModules = [ inputs.colmena.nixosModules.deploymentOptions ];
            };
        };
    getMasterSystem = clusterName: nodeId: getNixosSystem clusterName "master" nodeId;
    getWorkerSystem = clusterName: nodeId: getNixosSystem clusterName "worker" nodeId;
    getMasterIds = clusterConfig: range clusterConfig.masters.count;  # [ 0, 1, ...]
    getWorkerIds = clusterConfig: range clusterConfig.workers.count;

    # foreach cluster
    #   for i in range 0, masters.count:
    #     yield nixosSystem { ... }
    #   for i in range 0, workers.count:
    #     yield nixosSystem { ... }
    nixosConfigurations = builtins.foldl' (acc: clusterName:
        let
            clusterConfig = clusterConfigsSet.${clusterName};
            masterSystems = builtins.foldl' (acc: i: acc // (getMasterSystem clusterName i)) {} (getMasterIds clusterConfig);
            workerSystems = builtins.foldl' (acc: i: acc // (getWorkerSystem clusterName i)) {} (getWorkerIds clusterConfig);
        in
            acc // masterSystems // workerSystems
    ) {} (builtins.attrNames clusterConfigsSet);

    allSystemsBuilder = clusterName: pkgs: let 
            masterIds = getMasterIds clusterConfigsSet.${clusterName};
            workerIds = getWorkerIds clusterConfigsSet.${clusterName};
            allMasterNames = builtins.map (i: getNixosSystemName clusterName "master" i) masterIds;
            allWorkerNames = builtins.map (i: getNixosSystemName clusterName "worker" i) workerIds;
            allSystemNames = allMasterNames ++ allWorkerNames;
            allSystems = builtins.map (name: nixosConfigurations.${name}) allSystemNames;
            derivations = builtins.map (system: system.config.system.builder.package) allSystems;
            concatCommands = commands: builtins.concatStringsSep "\n" commands;
    in 
    pkgs.stdenv.mkDerivation {
        name = "build-all-${clusterName}";
        src = ./.;
        
        buildInputs = derivations;
        
        buildPhase = ''
            mkdir -p $out/images
            ${concatCommands (builtins.map (system: "ln -s -t $out/images ${system.config.system.builder.package}/${system.config.system.builder.outputDir}/*") allSystems)}

            echo "All systems of cluster ${clusterName} available in $out/images/ (i.e. result/images/)"
        '';
    };

    packages = {
        aarch64-linux = {
            build-all-k = allSystemsBuilder "k" (import inputs.nixpkgs { system = "aarch64-linux"; });
            master0-k-sd-image = nixosConfigurations.master0-k.config.system.build.sdImage;
            build-all-test = allSystemsBuilder "test" (import inputs.nixpkgs { system = "aarch64-linux"; });
        };
    };
in
{
    inherit nixosConfigurations;
    # inherit packages;
    packages = {};
}