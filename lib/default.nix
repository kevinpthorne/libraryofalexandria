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
    importYaml = import ./import-yaml.nix;
    pathIfExists = import ./path-if-exists.nix;
    fetchRke2Asset = import ./fetch-rke2-asset.nix;
    getRke2Arch = import ./get-rke2-arch.nix;
    getClusterConfig = import ./get-cluster-config.nix;
    range = n: builtins.genList (x: x) n;
}