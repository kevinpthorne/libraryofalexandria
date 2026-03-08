{ pkgs, config, lib, inputs, ... }:
{
    imports = [  # top installs last
        ./kube-admin-ui.nix
        ./argocd.nix
        ./cert-manager.nix
        ./longhorn.nix
    ];
}