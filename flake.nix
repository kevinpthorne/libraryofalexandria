{
  description = "A very basic flake";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-24.11";

    raspberry-pi-nix.url = "github:nix-community/raspberry-pi-nix/master";

    supported-arch.url = "github:nix-systems/default-linux";  # aarch64-linux and x86_64-linux
  };

  outputs = inputs @ { self, nixpkgs, supported-arch, ... }:
  let
    eachArch = nixpkgs.lib.genAttrs (import supported-arch);
    importableInputs = (builtins.removeAttrs inputs [ "self" ]);
    # deepMerge = import ./lib/deep-merge.nix nixpkgs.lib;
  in {

    # TODO what if we need aarch64 specific packages?
    packages =
    #  deepMerge [ 
    # # system-specific packages  
    # {
    #    aarch64-linux = {};
    # } 
    # # for every supported system
    eachArch (system: {
      hello = nixpkgs.legacyPackages.${system}.hello;
      runonce = nixpkgs.callPackage ./pkgs/runonce { };
    }) ;
    # ];

  };
}
