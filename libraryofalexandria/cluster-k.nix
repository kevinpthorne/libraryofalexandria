{ srcs, nixosModules }:
let
    master = clusterLabel: n:
        let 
            nStr = toString n;
            nMaster = import ./master.nix "rpi" "libraryofalexandria-${clusterLabel}" n;
        in {
            "libraryofalexandria-${clusterLabel}-master${nStr}-rpi" = srcs.nixpkgs.lib.nixosSystem {
                system = "aarch64-linux";
                modules = [ 
                    nixosModules.raspberry-pi 
                    nixosModules.sd-image 
                    nMaster
                ];
            };
        };
    worker = clusterLabel: n:
        let 
            nStr = toString n;
            nWorker = import ./worker.nix "rpi" "libraryofalexandria-${clusterLabel}" n;
        in {
            "libraryofalexandria-${clusterLabel}-worker${nStr}-rpi" = srcs.nixpkgs.lib.nixosSystem {
                system = "aarch64-linux";
                modules = [ 
                    nixosModules.raspberry-pi 
                    nixosModules.sd-image 
                    nWorker
                ];
            };
        };
in
import ./cluster.nix "k" master 2 worker 3