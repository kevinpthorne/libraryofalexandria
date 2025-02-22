{ pkgs, lib, config, ... }:
{
    options.system.builder = {
        package = lib.mkOption {
            type = lib.types.package;
        };

        outputDir = lib.mkOption {
            type = lib.types.str;
        };
    };
}