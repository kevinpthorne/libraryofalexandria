# Usage
# ...
# customLib = import ./lib;
# deepMerge = customLib.deepMerge nixpkgs.lib;
# ...
# customLib.importIfExists ./something
rec {
    deepMerge = import ./deep-merge.nix;
    importIfExists = import ./import-if-exists.nix;
    importIfExistsArgs = import ./import-if-exists-args.nix;
    pathIfExists = import ./path-if-exists.nix;
    range = n: builtins.genList (x: x) n;
}