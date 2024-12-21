let
    pkgs = import <nixpkgs> {};
    finalConfig = import ./render-node-config.nix;
    renderedNode = import ../node.nix finalConfig {pkgs=pkgs; lib=pkgs.lib;};
in
    renderedNode
