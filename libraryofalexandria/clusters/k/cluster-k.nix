{ srcs, nixosModules }:
let
    nodeConfig = clusterLabel: n: {
        lib = srcs.nixpkgs.lib;
        platform = "rpi";
        clusterLabel = clusterLabel;
        nodeNumber = n;
        k8s = {
            masterIp = "10.69.69.100";
            masterHostname = "master0-k"; # TODO fix this
            masterPort = 6443;
        };
    };
    master = clusterLabel: n:
        let 
            nStr = toString n;
            nMasterBaseConfig = (nodeConfig clusterLabel n) // { nodeType = "master"; };
            nMasterConfig = import ../../node.cfg.nix nMasterBaseConfig;
            nMaster = import ../../node.nix nMasterConfig;
        in {
            "libraryofalexandria-${clusterLabel}-master${nStr}-rpi" = srcs.nixpkgs.lib.nixosSystem {
                system = "aarch64-linux";
                modules = [ 
                    nixosModules.raspberry-pi 
                    nixosModules.sd-image
                    nMaster
                ];
                extraModules = [ srcs.colmena.nixosModules.deploymentOptions ];
            };
        };
    worker = clusterLabel: n:
        let 
            nStr = toString n;
            nWorkerBaseConfig = (nodeConfig clusterLabel n) // { nodeType = "worker"; };
            nWorkerConfig = import ../../node.cfg.nix nWorkerBaseConfig;
            nWorker = import ../../node.nix nWorkerBaseConfig;
        in {
            "libraryofalexandria-${clusterLabel}-worker${nStr}-rpi" = srcs.nixpkgs.lib.nixosSystem {
                system = "aarch64-linux";
                modules = [ 
                    nixosModules.raspberry-pi 
                    nixosModules.sd-image
                    nWorker
                ];
                extraModules = [ srcs.colmena.nixosModules.deploymentOptions ];
            };
        };
in
import ../cluster-gen.nix "k" master 1 worker 4