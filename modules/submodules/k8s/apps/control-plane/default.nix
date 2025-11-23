{ pkgs, config, lib, inputs, ... }:
{
    imports = [  # top installs last
        ./argocd.nix
        ./vault.nix
        ./cert-manager.nix
        ./longhorn.nix
    ];

    config = {
        libraryofalexandria.apps = {
            argocd.enable = true;
            vault.enable = true;
            cert-manager.enable = true;
            longhorn.enable = true;
        };
    };
}