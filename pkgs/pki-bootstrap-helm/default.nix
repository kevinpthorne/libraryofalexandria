{ pkgs ? import <nixpkgs> { }, ... }:
let
    lib2 = import ../../lib;
    importYaml = lib2.importYaml { inherit pkgs; };
    chartYaml = importYaml ./Chart.yaml;
in
pkgs.stdenv.mkDerivation {
    name = "pki-bootstrap-helm";
    version = chartYaml.version; # read from chart.yaml

    src = ./.;

    phases = [ "installPhase" ];
    installPhase = ''
      cp -r "$src" "$out"
    '';
}