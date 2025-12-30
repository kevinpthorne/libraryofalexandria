{ pkgs, config, lib, inputs, ... }:
{
    imports = [  # top installs last
        ./argocd.nix
        ./eso.nix
        ./cert-manager.nix
        ./longhorn.nix
    ];
}