{ pkgs, config, lib, inputs, ... }:
{
    imports = [  # top installs last
        ./argocd.nix
        ./crossplane.nix
        ./vault.nix
        ./cert-manager.nix
        ./longhorn.nix
    ];

    config = {
        libraryofalexandria.apps = {
            crossplane.enable = true;
            argocd.enable = true;
            vault.enable = true;
            cert-manager.enable = true;
            longhorn.enable = true;
        };
    };
}