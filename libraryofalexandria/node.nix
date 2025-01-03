{ nodeType, platform, clusterLabel, nodeNumber, ... } @ nodeConfig:
{ pkgs, lib, ... }:
let 
    importIfExists = import ../libraryofalexandria/logic/import-if-exists.nix;
    deepMerge = import ../libraryofalexandria/logic/deep-merge.nix lib;
    # render config
    finalConfig = import ./node.cfg.nix nodeConfig;
    # render nixos module
    args = { pkgs=pkgs; lib=lib; };
    base = import ../libraryofalexandria/defaults.nix finalConfig args;
    nodeTypeBase = importIfExists  ../libraryofalexandria/${nodeType}.nix finalConfig args;
    platformOverrides = importIfExists  ../libraryofalexandria/platforms/${platform}/${nodeType}.nix finalConfig args;
    clusterOverrides = importIfExists ../libraryofalexandria/clusters/${clusterLabel}/default.nix finalConfig args;
    nodeTypeOverrides = importIfExists ../libraryofalexandria/clusters/${clusterLabel}/${nodeType}.nix finalConfig args;
    n = toString nodeNumber;
    nodeOverrides = importIfExists ../libraryofalexandria/clusters/${clusterLabel}/${nodeType}-${n}.nix finalConfig args;
in
deepMerge [ 
    nodeOverrides
    nodeTypeOverrides
    clusterOverrides
    platformOverrides
    nodeTypeBase 
    base
    {
        options = {};
        config = {};
    } 
]