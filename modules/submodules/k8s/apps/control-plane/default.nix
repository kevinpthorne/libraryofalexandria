{ pkgs, config, lib, inputs, ... }:
{
    imports = [  # top installs last
        ./argocd.nix
        ./vault.nix
        ./spire.nix
        ./cert-manager.nix
        ./longhorn.nix
    ];
}