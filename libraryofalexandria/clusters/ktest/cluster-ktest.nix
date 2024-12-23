{ srcs, nixosModules }:
let
    master = clusterLabel: n:
        let 
            nStr = toString n;
            nMasterBaseConfig = {
                lib = srcs.nixpkgs.lib;
                platform = "x86_64";
                clusterLabel = clusterLabel;
                nodeNumber = n;
                nodeType = "master";
            };
            nMasterConfig = import ../../node.cfg.nix nMasterBaseConfig;
            nMaster = import ../../node.nix nMasterConfig;
        in {
            "libraryofalexandria-${clusterLabel}-master${nStr}" = srcs.nixpkgs.lib.nixosSystem {
                system = "x86_64-linux";
                modules = [
                    ({ modulesPath, ... }: {
                        imports = [ 
                            (modulesPath + "/installer/cd-dvd/installation-cd-minimal.nix")
                            (modulesPath + "/installer/cd-dvd/channel.nix")
                        ];
                    })
                    nMaster
                    srcs.disko.nixosModules.disko
                ];
                extraModules = [ srcs.colmena.nixosModules.deploymentOptions ];
            };
        };
    worker = clusterLabel: n:
        let 
            nStr = toString n;
            nWorkerBaseConfig = {
                lib = srcs.nixpkgs.lib;
                platform = "rpi";
                clusterLabel = clusterLabel;
                nodeNumber = n;
                nodeType = "worker";
            };
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
import ../cluster-gen.nix "ktest" master 1 worker 1