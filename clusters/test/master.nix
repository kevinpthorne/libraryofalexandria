{ pkgs, lib, ... }:
{
    config = {
        libraryofalexandria.node = {
            type = "master";
        };
    };
}