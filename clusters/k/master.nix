{ pkgs, lib, ... }:
{
    config = {
        libraryofalexandria.node = {
            nodeType = "master";
        };
    };
}