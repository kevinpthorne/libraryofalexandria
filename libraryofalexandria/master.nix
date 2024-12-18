platform: hostnamePrefix: nodeNumber:
{ pkgs, lib, ... }:
let
    base = import ../libraryofalexandria/defaults.nix {};
    platformBase = import ../libraryofalexandria/platforms/${platform} {
        isMaster = true;
        nodeNumber = nodeNumber;
        hostnamePrefix = hostnamePrefix;
    };
    overrides = import ../libraryofalexandria/platforms/${platform}/master.nix {};
in
{
    options = {};
    config = {} // base // platformBase // overrides;
}