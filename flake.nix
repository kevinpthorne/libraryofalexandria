{
  description = "Library of Alexandria cluster definition";

  inputs = {
    nixos-raspberrypi = {
      url = "github:nvmd/nixos-raspberrypi/main";
      inputs.flake-compat.follows = "flake-compat";
    };

    nixpkgs = {
      follows = "nixos-raspberrypi/nixpkgs";
    };

    flake-compat = {
      url = "github:edolstra/flake-compat";
      flake = false;
    };

    supported-arch.url = "github:nix-systems/default-linux"; # aarch64-linux and x86_64-linux

    deploy-rs = {
      url = "github:serokell/deploy-rs";
      inputs.nixpkgs.follows = "nixpkgs";
      inputs.flake-compat.follows = "flake-compat";
    };

    colmena = {
      url = "github:zhaofengli/colmena";
      inputs = {
        nixpkgs.follows = "nixpkgs";
        stable.follows = "nixpkgs";
        flake-compat.follows = "flake-compat";
      };
    };

    disko = {
      url = "github:nix-community/disko/latest";
      inputs = {
        nixpkgs.follows = "nixpkgs";
      };
    };

    kubegen = {
      url = "github:farcaller/nix-kube-generators";
    };
    kubenix = {
      url = "github:hall/kubenix";
      inputs.nixpkgs.follows = "nixpkgs";
      inputs.flake-compat.follows = "flake-compat";
    };

    nixos-stig = {
      url = "github:kevinpthorne/nixos-stig";
    };
  };

  nixConfig = {
    extra-substituters = [
      "https://nixos-raspberrypi.cachix.org"
      "https://p2p-vpn.cachix.org"
      "https://libraryofalexandria.cachix.org"
    ];
    extra-trusted-public-keys = [
      "nixos-raspberrypi.cachix.org-1:4iMO9LXa8BqhU+Rpg6LQKiGa2lsNh/j2oiYLNOQ5sPI="
      "p2p-vpn.cachix.org-1:tH4Izgml6yIvPksO7CL3AgmorgMFn601Nto/qgQYAuk="
      "libraryofalexandria.cachix.org-1:0LK2J/wWh2hTvOYz10cRcsjCQP5zh/3q7xm5Z4+77bA="
    ];
  };

  outputs =
    inputs@{
      self,
      nixpkgs,
      supported-arch,
      nixos-stig,
      colmena,
      ...
    }:
    let
      customLib = import ./lib;
      localPkgs = import ./pkgs nixpkgs;
      eachArch = nixpkgs.lib.genAttrs (import supported-arch);
      importableInputs = (
        builtins.removeAttrs inputs [
          "self"
          "config"
        ]
      );
      deepMerge = customLib.deepMerge nixpkgs.lib;
      kubelib = inputs.kubegen.lib { pkgs = nixpkgs; };
      clusters = import ./clusters (
        importableInputs
        // {
          inherit eachArch;
          inherit localPkgs;
        }
      );
    in
    {

      overlays = {
        # runonce = import ./pkgs/runonce
        # runonce = final: prev: { runonce = import ./pkgs/runonce final; };
        localPkgs = final: prev: localPkgs final;
      };

      nixosConfigurations = {
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
      # deploy = clusters.deploy-rs;
      clusters = clusters;

      packages = deepMerge [
        # system-specific packages
        {
          aarch64-linux = { };
        }
        # for every supported system
        (eachArch (
          system:
          let
            systemPkgs = import nixpkgs {
              inherit system;
              overlays = with self.overlays; [ localPkgs ];
            };
          in
          {
            hello = nixpkgs.legacyPackages.${system}.hello;
            # runonce = systemPkgs.runonce;
          }
          // localPkgs systemPkgs systemPkgs
        ))
        clusters.packages
      ];

      apps = eachArch (
        system:
        let
          systemPkgs = import nixpkgs {
            inherit system;
            overlays = with self.overlays; [ localPkgs ];
          };
        in
        {
          colmena = {
            type = "app";
            program = "${systemPkgs.colmena}/bin/colmena";
          };
          deploy = {
            type = "app";
            program = "${systemPkgs.deploy-rs}/bin/deploy-rs";
          };
        }
      );

      # checks = deepMerge [
      #   (eachArch (
      #     system:
      #     let
      #       systemPkgs = import nixpkgs {
      #         inherit system;
      #         overlays = with self.overlays; [ localPkgs ];
      #       };
      #     in
      #     {
      #       # helloTest = systemPkgs.callPackage ./tests/clusters/test/k8s-boot.nix {
      #       #   cluster = clusters.by_name.test;
      #       # };
      #       getHostIdTest = systemPkgs.callPackage ./tests/lib/get-host-id.nix (with systemPkgs; { inherit lib; });
      #     }
      #   ))
      # ];

    };
}
