{ pkgs, config, lib, inputs, ... }:
{
    imports = [  # top installs last
        ./loa-extras.nix
        ./loa-core.nix
    ];

    config = {
        libraryofalexandria.apps = {
            loa-extras.enable = false;
            loa-core.enable = true;
        };
    };
}