{
  pkgs,
  clusterName ? "unknown",
  cluster ? {},
  ...
}:
let
  clusterJsonFile = pkgs.writeText "cluster-${clusterName}.json" (builtins.toJSON cluster);
in
pkgs.runCommand "cluster-${clusterName}" { } ''
  set -x

  mkdir $out
  cp ${clusterJsonFile} $out/cluster-${clusterName}.json

  set +x
''
