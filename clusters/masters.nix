{ lib, ... }:
{
    options.libraryofalexandria.cluster.masters = (import ./nodes.nix lib) // {
        ips = lib.mkOption {
            type = lib.types.listOf lib.types.str;
            description = "List of master IPs in node-order";
        };
    };
}