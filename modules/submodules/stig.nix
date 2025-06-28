{ pkgs, config, lib, inputs, ... }:
{
    imports = [
        inputs.nixos-stig.nixosModules.nixos-stig
    ];

    config = {
        stig.enable = true;
    };
}