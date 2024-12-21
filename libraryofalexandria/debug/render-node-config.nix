let
    pkgs = import <nixpkgs> {};
    startingConfig = {
        lib = pkgs.lib;
        platform = "rpi";
        clusterLabel = "test";
        nodeNumber = 0;
        nodeType = "master";
    };
    renderedNodeConfig = import ../node.cfg.nix startingConfig;
in
renderedNodeConfig