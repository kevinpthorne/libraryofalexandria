# Merge multiple attribute sets, prioritizing earlier sets
# 
# example usage
# let
#   deepMerge = import ./logic/deep-merge.nix
#   attrSet1 = { a = 1; b = 2; c = { x = 3; y = 4; } };
#   attrSet2 = { b = 5; c = { y = 6; z = 7; } };
#   attrSet3 = { d = 8; c = { x = 9; } };
# in
#   deepMerge [ attrSet1 attrSet2 attrSet3 ];
let
    pkgs = import <nixpkgs> {};
    lib = pkgs.lib;
in
  let
    merge = 
      acc: new: lib.recursiveUpdate new acc;
  in
    builtins.foldl merge {}