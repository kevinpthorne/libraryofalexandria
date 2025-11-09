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

    disko = {
      url = "github:nix-community/disko/latest";
      inputs = {
        nixpkgs.follows = "nixpkgs";
      };
    };

    nixos-stig.url = "github:kevinpthorne/nixos-stig";
  };

  outputs = inputs @ { self, nixpkgs, supported-arch, raspberry-pi-nix, nixos-stig, ... }:
  let
    eachArch = nixpkgs.lib.genAttrs (import supported-arch);
    importableInputs = (builtins.removeAttrs inputs [ "self" "config" ]);
    customLib = import ./lib;
    deepMerge = customLib.deepMerge nixpkgs.lib;
    clusters = import ./clusters (importableInputs // {
      inherit eachArch;
    });
  in {

    overlays = {
      # runonce = import ./pkgs/runonce 
      runonce = final: prev: { runonce = import ./pkgs/runonce final; };
    };

    nixosConfigurations = {
      rpi-example = inputs.raspberry-pi-nix.nixosConfigurations.rpi-example;

      # test = let 
      #   config = import ./clusters/k importableInputs; 
      # in 
      #   nixpkgs.lib.nixosSystem {
      #     system = config.system;
      #     modules = config.masters.modules 0;
      #     extraModules = [ inputs.colmena.nixosModules.deploymentOptions ];
      #   };
    } 
    // clusters.nixosConfigurations;

    colmena = clusters.colmena;

    packages = deepMerge [ 
      # system-specific packages  
      {
        aarch64-linux = {};
      } 
      # for every supported system
      (eachArch (system: 
        let
          systemPkgs = import nixpkgs {
            inherit system;
            overlays = with self.overlays; [ runonce ];
          };
        in
        {
          hello = nixpkgs.legacyPackages.${system}.hello;
          runonce = systemPkgs.runonce;
        })
      )
      clusters.packages
    ];

    # checks = deepMerge [
    #    (eachArch (system:
    #     let
    #       systemPkgs = import nixpkgs {
    #         inherit system;
    #         overlays = with self.overlays; [ runonce ];
    #       };
    #     in
    #     {
    #       helloTest = systemPkgs.callPackage ./tests/clusters/test/k8s-boot.nix { 
    #         cluster = clusters.by_name.test;
    #       };
    #     })
    #    ) 
    # ];

  };
}
