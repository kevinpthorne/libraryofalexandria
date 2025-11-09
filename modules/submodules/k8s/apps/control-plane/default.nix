{ pkgs, config, lib, inputs, ... }:
{
    imports = [  # top installs last
        ./rancher.nix
        ./argocd.nix
        ./vault.nix
        ./cert-manager.nix
        ./longhorn.nix
    ];

    config = {
        libraryofalexandria.apps = {
            rancher.enable = true;
            argocd.enable = true;
            vault.enable = true;
            cert-manager.enable = true;
            longhorn.enable = true;
        };
    };
}