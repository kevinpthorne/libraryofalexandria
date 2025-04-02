{ pkgs, config, lib, inputs, ... }:
{
    imports = [
        ./submodules/control-plane/nginx-ingress.nix
    ];
}