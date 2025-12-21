{ pkgs, config, lib, inputs, ... }:
{
    imports = [  # top installs last
        ./argocd.nix
        ./vault.nix
        ./cert-manager.nix
        ./longhorn.nix
    ];
}