{ self, cluster, pkgs }:
pkgs.nixosTest ({
#   imports = [ ./k8s-boot.nix ];
} // import ./k8s-boot.nix { inherit cluster })