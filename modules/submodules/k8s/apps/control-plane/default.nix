{ pkgs, config, lib, inputs, ... }:
{
    imports = [  # top installs last
        ./argocd.nix
        ./vault.nix
        ./spire.nix
        ./cert-manager.nix
        ./longhorn.nix
    ];

    config = {
        libraryofalexandria.apps = {
            argocd.enable = true;
            vault.enable = true;
            spire.enable = true;
            cert-manager.enable = true;
            longhorn.enable = true;
        };
    };
}