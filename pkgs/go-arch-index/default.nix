{ pkgs, lib, lib2, clusterName ? "unknown", nixosConfigurations ? {}, ... }:
let
  goArchs = lib.unique (
                      builtins.map 
                        (sys: lib2.getGoArch { pkgs = sys.config.nixpkgs; }) 
                        (builtins.attrValues nixosConfigurations)
                  );
  archsJsonFile = pkgs.writeText "go-arch-index-source.json" (builtins.toJSON goArchs);
in
pkgs.runCommand "go-arch-index-${clusterName}" {} ''
  set -x

  mkdir $out
  cp ${archsJsonFile} $out/go-arch-index.json

  set +x
''