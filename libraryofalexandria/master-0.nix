{ pkgs, lib, ... }:
let
    master = import ./master.nix {
        hostnamePrefix = "libraryofalexandria-a";
        nodeNumber = 0;
    };
in
master { pkgs=pkgs; lib=lib; } // {
    
}