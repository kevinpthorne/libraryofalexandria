{ lib, nodeType, platform, clusterLabel, nodeNumber, ... } @ nodeConfig:
let 
    importIfExists = import ./logic/import-if-exists.cfg.nix;
    deepMerge = import ./logic/deep-merge.nix lib;
    mergeConfig = nodeConfig: importStmt: deepMerge [ (importStmt nodeConfig) nodeConfig ];
    # Enter each
    basePre = mergeConfig nodeConfig (importIfExists ./defaults.cfg.nix true);
    nodeTypeBasePre = mergeConfig basePre (importIfExists  ./${nodeType}.cfg.nix true);
    platformOverridesPre = mergeConfig nodeTypeBasePre (importIfExists  ./platforms/${platform}/${nodeType}.cfg.nix true);
    nodeTypeOverridesPre = mergeConfig platformOverridesPre (importIfExists ./clusters/${clusterLabel}/${nodeType}.cfg.nix true);
    nodeOverridesPre = mergeConfig nodeTypeOverridesPre (importIfExists ./clusters/${clusterLabel}/${nodeType}-${toString nodeNumber}.cfg.nix true);
    # Exit each
    base = mergeConfig nodeOverridesPre (importIfExists ./defaults.cfg.nix false);
    nodeTypeBase = mergeConfig base (importIfExists  ./${nodeType}.cfg.nix false);
    platformOverrides = mergeConfig nodeTypeBase (importIfExists  ./platforms/${platform}/${nodeType}.cfg.nix false);
    nodeTypeOverrides = mergeConfig platformOverrides (importIfExists ./clusters/${clusterLabel}/${nodeType}.cfg.nix false);
    nodeOverrides = mergeConfig nodeTypeOverrides (importIfExists ./clusters/${clusterLabel}/${nodeType}-${toString nodeNumber}.cfg.nix false);
    # 
    renderedConfig = nodeOverrides;
in
renderedConfig
# builtins.trace renderedConfig renderedConfig