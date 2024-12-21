{ lib, nodeType, platform, clusterLabel, nodeNumber, ... } @ nodeConfig:
let 
    importIfExists = import ./logic/import-if-exists.cfg.nix;
    deepMerge = import ./logic/deep-merge.nix lib;
    #
    _nodeConfig = nodeConfig // { 
        isMaster = if nodeType == "master" then true else false;
    };
    #
    base = importIfExists ./defaults.cfg.nix _nodeConfig;
    nodeTypeBase = importIfExists  ./${nodeType}.cfg.nix _nodeConfig;
    platformOverrides = importIfExists  ./platforms/${platform}/${nodeType}.cfg.nix _nodeConfig;
    nodeTypeOverrides = importIfExists ./clusters/${clusterLabel}/${nodeType}.cfg.nix _nodeConfig;
    n = toString nodeNumber;
    nodeOverrides = importIfExists ./clusters/${clusterLabel}/${nodeType}-${n}.cfg.nix _nodeConfig;
in
deepMerge [ 
    nodeOverrides
    nodeTypeOverrides
    platformOverrides
    nodeTypeBase 
    base 
    {}
    _nodeConfig 
]