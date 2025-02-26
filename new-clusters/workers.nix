{ lib, ... }:
{
    options.libraryofalexandria.cluster.workers = (import ./nodes.nix lib);
}