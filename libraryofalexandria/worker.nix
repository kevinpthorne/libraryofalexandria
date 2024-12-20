platform: hostnamePrefix: nodeNumber:
{ pkgs, lib, ... }:
let
    base = import ../libraryofalexandria/defaults.nix {} { pkgs=pkgs; lib=lib; };
    platformBase = import ../libraryofalexandria/platforms/${platform} {
        isMaster = false;
        nodeNumber = nodeNumber;
        hostnamePrefix = hostnamePrefix;
    } { pkgs=pkgs; lib=lib; };
    overrides = import ../libraryofalexandria/platforms/${platform}/worker.nix {} { pkgs=pkgs; lib=lib; };
    deepMerge = import ../libraryofalexandria/logic/deep-merge.nix;
in
deepMerge [ overrides platformBase base {
    options = {};
    config = {};
} ]