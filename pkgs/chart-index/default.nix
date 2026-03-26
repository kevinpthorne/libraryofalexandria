{ pkgs, clusterName ? "unknown", charts ? [], ... }:
let
  chartsSpecs = builtins.map (chartConfig: builtins.removeAttrs chartConfig [ "chartLocks" "chartPackage" "valuesPackage" "imagePackages" "chartLock" ]) charts;
  chartsJsonFile = pkgs.writeText "chart-index-source.json" (builtins.toJSON chartsSpecs);
in
pkgs.runCommand "chart-index-${clusterName}" {} ''
  set -x

  mkdir $out
  cp ${chartsJsonFile} $out/chart-index.json

  set +x
''