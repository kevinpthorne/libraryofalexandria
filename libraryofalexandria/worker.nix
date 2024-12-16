platform: hostnamePrefix: nodeNumber:
{ pkgs, lib, ... }:
let
    base = import ../libraryofalexandria/platforms/${platform} {
        isMaster = false;
        nodeNumber = nodeNumber;
        hostnamePrefix = hostnamePrefix;
    };
    overrides = import ../libraryofalexandria/platforms/${platform}/worker.nix {};
in
{
    options = {};
    config = {} // base // overrides;
}