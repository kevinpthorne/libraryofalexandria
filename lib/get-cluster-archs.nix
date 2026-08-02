{ cluster, ... }:
let
  getGoArch = import ./get-go-arch.nix;
  archs = builtins.map (node: getGoArch {
    pkgs = { stdenv.hostPlatform.system = node.config.nixpkgs.hostPlatform.system; };
  }) (builtins.attrValues cluster.nodes);
in
builtins.foldl' (acc: elem: if builtins.elem elem acc then acc else acc ++ [ elem ]) [] archs
