{
  description = "Library of Alexandria cluster definition";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-24.11";

    raspberry-pi-nix.url = "github:nix-community/raspberry-pi-nix/master";

    supported-arch.url = "github:nix-systems/default-linux";  # aarch64-linux and x86_64-linux
    
    colmena = {
      url = "github:zhaofengli/colmena";
      inputs = {
        nixpkgs.follows = "nixpkgs";
        stable.follows = "nixpkgs";
      };
    };
  };

  outputs = inputs @ { self, nixpkgs, supported-arch, raspberry-pi-nix, ... }:
  let
    eachArch = nixpkgs.lib.genAttrs (import supported-arch);
    importableInputs = (builtins.removeAttrs inputs [ "self" ]);
    # deepMerge = import ./lib/deep-merge.nix nixpkgs.lib;
  in {

    overlays = {
      # runonce = import ./pkgs/runonce 
      runonce = final: prev: { runonce = import ./pkgs/runonce final; };
    };

    nixosConfigurations = {
      rpi-example = nixpkgs.lib.nixosSystem {
        system = "aarch64-linux";
        modules = [ 
          raspberry-pi-nix.nixosModules.raspberry-pi
          raspberry-pi-nix.nixosModules.sd-image
          # ./example
        ];
      };

      test = let 
        config = import ./clusters/k importableInputs; 
      in 
        nixpkgs.lib.nixosSystem {
          system = config.system;
          modules = config.masters.modules 0;
          extraModules = [ inputs.colmena.nixosModules.deploymentOptions ];
        };
    };

    # TODO what if we need aarch64 specific packages?
    packages =
    #  deepMerge [ 
    # # system-specific packages  
    # {
    #    aarch64-linux = {};
    # } 
    # # for every supported system
    eachArch (system: 
    let
      systemPkgs = import nixpkgs {
        inherit system;
        overlays = with self.overlays; [ runonce ];
      };
    in
    {
      hello = nixpkgs.legacyPackages.${system}.hello;
      runonce = systemPkgs.runonce;
    }) ;
    # ];

  };
}
