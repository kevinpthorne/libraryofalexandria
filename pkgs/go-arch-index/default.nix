{
  pkgs,
  lib,
  clusterName ? "unknown",
  nixosConfigurations ? { },
  ...
}:
let
  lib2 = import ../../lib;
  goArchs = lib.unique (
    builtins.map (
      sys:
      lib2.getGoArch {
        pkgs = import sys.config.nixpkgs { hostPlatform = sys.config.nixpkgs.hostPlatform.system; };
      }
    ) (builtins.attrValues nixosConfigurations)
  );
  archsJsonFile = pkgs.writeText "go-arch-index-source.json" (builtins.toJSON goArchs);
in
pkgs.runCommand "go-arch-index-${clusterName}" { } ''
  set -x

  mkdir $out
  cp ${archsJsonFile} $out/go-arch-index.json

  set +x
''
