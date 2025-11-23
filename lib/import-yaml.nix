{ pkgs, ... }:
file:
# 1. Create a derivation (IFD) to convert YAML to JSON
let
    jsonOutputDrv = pkgs.runCommand "converted-yaml.json" {
        inherit file;
        preferLocalBuild = true; # Improves performance in some contexts
        # The output path of the derivation
        output = "$out";
    } ''
    # Execute yq to read the YAML file, convert to JSON (-o json),
    # and write the result to the $out file.
    ${pkgs.yq-go}/bin/yq -o json '.' ${file} > $out
    '';
    jsonFile = builtins.readFile jsonOutputDrv;
in
# 2. Read the resulting JSON file and convert it to a Nix attribute set
builtins.fromJSON jsonFile