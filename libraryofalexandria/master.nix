platform: hostnamePrefix: nodeNumber:
{ pkgs, lib, ... }:
let
    base = import ../libraryofalexandria/defaults.nix {} { pkgs=pkgs; lib=lib; };
    platformBase = import ../libraryofalexandria/platforms/${platform} {
        isMaster = true;
        nodeNumber = nodeNumber;
        hostnamePrefix = hostnamePrefix;
    } { pkgs=pkgs; lib=lib; };
    overrides = import ../libraryofalexandria/platforms/${platform}/master.nix {} { pkgs=pkgs; lib=lib; };
in
{
    options = {};
    config = {};
} // base // platformBase // overrides