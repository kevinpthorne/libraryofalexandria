{
  description = "Library of Alexandria cluster definition";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-25.11";

    nixos-raspberrypi.url = "github:nvmd/nixos-raspberrypi/main";

    supported-arch.url = "github:nix-systems/default-linux"; # aarch64-linux and x86_64-linux

    deploy-rs = {
      url = "github:serokell/deploy-rs";
      inputs.nixpkgs.follows = "nixpkgs";
    };

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

    kubegen.url = "github:farcaller/nix-kube-generators";
    kubenix.url = "github:hall/kubenix";

    nixos-stig.url = "github:kevinpthorne/nixos-stig";
  };

  nixConfig = {
    extra-substituters = [
      "https://nixos-raspberrypi.cachix.org"
    ];
    extra-trusted-public-keys = [
      "nixos-raspberrypi.cachix.org-1:4iMO9LXa8BqhU+Rpg6LQKiGa2lsNh/j2oiYLNOQ5sPI="
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
