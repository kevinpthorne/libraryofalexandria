src:
{
  pkgs ? import <nixpkgs> { },
  ...
}:
let
  lib2 = import ./.;
  importYaml = lib2.importYaml { inherit pkgs; };
  chartYaml = importYaml "${src}/Chart.yaml";
in
pkgs.stdenv.mkDerivation {
  name = chartYaml.name;
  version = chartYaml.version; # read from chart.yaml

  inherit src;

  phases = [
    "buildPhase"
  ];
  buildPhase = ''
    ${pkgs.kubernetes-helm}/bin/helm package $src -d $out
    mkdir -p $out/src
    cp -r "$src"/* $out/src
  '';
}
