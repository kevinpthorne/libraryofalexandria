{ pkgs, config, lib, inputs, ... }:
{
    imports = [  # top installs last
        ./grafana.nix
        ./istio.nix
        ./argocd.nix
        ./vault.nix
        ./cert-manager.nix
        ./prometheus.nix
        ./rook-ceph.nix
    ];

    config = {
        libraryofalexandria.apps = {
            grafana.enable = true;
            istio.enable = true;
            argocd.enable = true;
            vault.enable = true;
            cert-manager.enable = true;
            rook-ceph.enable = true;
            prometheus.enable = true;
        };
    };
}