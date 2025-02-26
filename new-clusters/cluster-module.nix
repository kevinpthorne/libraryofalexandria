{ config, lib, inputs, eachArch, ... }:
let
    range = n: builtins.genList (x: x) n;
in
{
    imports = [
        ./masters.nix
        ./workers.nix
    ];

    options = {
        libraryofalexandria.cluster = {
            name = lib.mkOption {
                type = lib.types.str;
            };

            masters = lib.mkOption {
                type = lib.types.submodule (import ./masters.nix); # ??
            };

            workers = lib.mkOption {
                type = lib.types.submodule (import ./workers.nix);
            };
        };
        # rendered options, never given outside this module
        masters = lib.mkOption {
            readOnly = true;
        };
        workers = lib.mkOption {
            readOnly = true;
        };
        nodes = lib.mkOption {
            readOnly = true;
        };
        nixosConfigurations = lib.mkOption {
            readOnly = true;
        };
        packages = lib.mkOption {
            readOnly = true;
        };
    };

    config = let 
        getNixosSystem = nodeType: nodeId: lib.nixosSystem {
            modules = config.libraryofalexandria.cluster."${nodeType}s".modules nodeId;
            extraModules = [ inputs.colmena.nixosModules.deploymentOptions ];
            specialArgs = {
                inherit inputs;
            };
        };
        wrapNixosSystem = nixosSystem: {
           "${nixosSystem.config.libraryofalexandria.node.hostname}" = nixosSystem; 
        };
        getMasterSystem = nodeId: getNixosSystem "master" nodeId;
        getWorkerSystem = nodeId: getNixosSystem "worker" nodeId;
        masterIds = range config.libraryofalexandria.cluster.masters.count;  # [ 0, 1, ...]
        workerIds = range config.libraryofalexandria.cluster.workers.count;
        masterSystems = builtins.map (id: getMasterSystem id) masterIds;
        workerSystems = builtins.map (id: getWorkerSystem id) workerIds;
        allSystems = masterSystems ++ workerSystems;

        collectSystems = systemsList: builtins.foldl' (otherSystemsSet: systemSet: 
            otherSystemsSet // systemSet
        ) {} (builtins.map (system: wrapNixosSystem system) systemsList); 

        collectAll = attrGenerator: builtins.foldl' (acc: id:
            acc // attrGenerator id
        ) {};
        

        allSystemsBuilder = pkgs: let 
            clusterName = config.libraryofalexandria.cluster.name;
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
    in {
        # masters = collectAll (id: wrapNixosSystem id) masterSystems;
        masters = collectSystems masterSystems;
        # masters
        # ..master0
        # ..master1
        workers = collectSystems workerSystems;
        # workers
        # ..worker0
        # ..worker1
        # nodes = masters // workers
        nodes = config.masters // config.workers;
        #  
        # nixosConfigurations = nodes
        nixosConfigurations = config.nodes;
        # packages
        # ..build-all-${clusterName}
        # packages = {};
        packages = eachArch (arch: let 
            pkgs = import inputs.nixpkgs {
                system = arch;
            };
        in {
            "build-all-${config.libraryofalexandria.cluster.name}" = allSystemsBuilder pkgs;  # TODO this technically names the package twice - why not once?
        });
    };
}