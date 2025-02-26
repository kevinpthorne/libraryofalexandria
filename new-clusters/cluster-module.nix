{ config, lib, inputs, ... }:
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
    };

    config = let 
        getNixosSystemName = nodeType: nodeId: "${nodeType}${toString nodeId}-${config.libraryofalexandria.cluster.name}";
        getNixosSystem = builtins.break (nodeType: nodeId: {
            "${(getNixosSystemName nodeType nodeId)}" = lib.nixosSystem {
                modules = config.libraryofalexandria.cluster."${nodeType}s".modules nodeId;
                extraModules = [ inputs.colmena.nixosModules.deploymentOptions ];
                specialArgs = {
                    inherit inputs;
                };
            };
        });
        getMasterSystem = nodeId: getNixosSystem "master" nodeId;
        getWorkerSystem = nodeId: getNixosSystem "worker" nodeId;
        masterIds = range config.libraryofalexandria.cluster.masters.count;  # [ 0, 1, ...]
        workerIds = range config.libraryofalexandria.cluster.workers.count;

        collectAll = attrGenerator: builtins.foldl' (acc: id:
            acc // attrGenerator id
        ) {};
    in {
        masters = collectAll (id: getMasterSystem id) masterIds;
        # masters
        # ..master0
        # ..master1
        workers = collectAll (id: getWorkerSystem id) workerIds;
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
        
    };
}