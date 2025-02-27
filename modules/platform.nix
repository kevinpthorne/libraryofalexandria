{ lib, ... }:
{
    options.libraryofalexandria.node.platform = lib.mkOption {
        type = lib.types.str;
        readOnly = true;
    };
}