{ pkgs, config, lib, inputs, ... }:
{
    imports = [  # top installs last
        ./headlamp.nix
        ./argocd.nix
        ./trust-manager.nix
        ./cert-manager.nix
        ./longhorn.nix
    ];
}