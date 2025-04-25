{ pkgs, config, lib, inputs, ... }:
{
    imports = [  # top installs last
        ./istio.nix
        ./argocd.nix
        ./vault.nix
        ./cert-manager.nix
        ./rook-ceph.nix
        ./prometheus.nix
    ];

    config = {
        libraryofalexandria.apps = {
            istio.enable = true;
            argocd.enable = true;
            vault.enable = true;
            cert-manager.enable = true;
            rook-ceph.enable = true;
            prometheus.enable = true;
        };
    };
}