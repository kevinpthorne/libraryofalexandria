{
  description = "raspberry-pi nixos configuration";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-24.05";
    u-boot-src = {
      flake = false;
      url = "https://ftp.denx.de/pub/u-boot/u-boot-2024.07.tar.bz2";
    };
    rpi-linux-6_6_54-src = {
      flake = false;
      url = "github:raspberrypi/linux/rpi-6.6.y";
    };
    rpi-linux-6_10_12-src = {
      flake = false;
      url = "github:raspberrypi/linux/rpi-6.10.y";
    };
    rpi-firmware-src = {
      flake = false;
      url = "github:raspberrypi/firmware/1.20241001";
    };
    rpi-firmware-nonfree-src = {
      flake = false;
      url = "github:RPi-Distro/firmware-nonfree/bookworm";
    };
    rpi-bluez-firmware-src = {
      flake = false;
      url = "github:RPi-Distro/bluez-firmware/bookworm";
    };
    rpicam-apps-src = {
      flake = false;
      url = "github:raspberrypi/rpicam-apps/v1.5.2";
    };
    libcamera-src = {
      flake = false;
      url = "github:raspberrypi/libcamera/69a894c4adad524d3063dd027f5c4774485cf9db"; # v0.3.1+rpt20240906
    };
    libpisp-src = {
      flake = false;
      url = "github:raspberrypi/libpisp/v1.0.7";
    };
    colmena = {
      url = "github:zhaofengli/colmena";
      inputs = {
        nixpkgs.follows = "nixpkgs";
        stable.follows = "nixpkgs";
      };
    };
  };

  outputs = srcs@{ self, ... }:
    let
      pinned = import srcs.nixpkgs {
        system = "aarch64-linux";
        overlays = with self.overlays; [ core libcamera ];
      };
      clusterList = import ./libraryofalexandria/clusters-list.nix;
    in
    {
      overlays = {
        core = import ./rpi/overlays (builtins.removeAttrs srcs [ "self" ]);
        libcamera = import ./rpi/overlays/libcamera.nix (builtins.removeAttrs srcs [ "self" ]);
      };
      nixosModules = {
        raspberry-pi = import ./rpi {
          inherit pinned;
          core-overlay = self.overlays.core;
          libcamera-overlay = self.overlays.libcamera;
        };
        sd-image = import ./rpi/sd-image;
      };
      nixosConfigurations = {
        # rpi-example = srcs.nixpkgs.lib.nixosSystem {
        #   system = "aarch64-linux";
        #   modules = [ self.nixosModules.raspberry-pi self.nixosModules.sd-image ./example ];
        # };

        # dummy0-rpi = srcs.nixpkgs.lib.nixosSystem {
        #   system = "aarch64-linux";
        #   modules = [ self.nixosModules.raspberry-pi self.nixosModules.sd-image ./libraryofalexandria/master-0.nix ];
        # };
      } // (let
          clustersConfigsList = builtins.map(label: 
            import ./libraryofalexandria/cluster-${label}.nix {
              srcs=srcs; 
              nixosModules=self.nixosModules;
          }) clusterList;
          clustersConfigs = builtins.foldl' (prev: cluster: prev // cluster) {} clustersConfigsList;
        in
          clustersConfigs
      );
      checks.aarch64-linux = self.packages.aarch64-linux;
      packages.aarch64-linux = with pinned.lib;
        let
          kernels =
            foldlAttrs f { } pinned.rpi-kernels;
          f = acc: kernel-version: board-attr-set:
            foldlAttrs
              (acc: board-version: drv: acc // {
                "linux-${kernel-version}-${board-version}" = drv;
              })
              acc
              board-attr-set;
        in
        {
          example-sd-image = self.nixosConfigurations.rpi-example.config.system.build.sdImage;
          firmware = pinned.raspberrypifw;
          libcamera = pinned.libcamera;
          wireless-firmware = pinned.raspberrypiWirelessFirmware;
          uboot-rpi-arm64 = pinned.uboot-rpi-arm64;
        } // kernels;
      colmena = {
        meta = {
          nixpkgs = pinned;
          nodeNixpkgs = builtins.mapAttrs (_: v: v.pkgs) self.nixosConfigurations;
          nodeSpecialArgs = builtins.mapAttrs (_: v: v._module.specialArgs) self.nixosConfigurations;
          specialArgs.lib = pinned.lib;
        };
      } // builtins.mapAttrs (name: value: {
        nixpkgs.system = value.config.nixpkgs.system;
        imports = value._module.args.modules;
      }) (self.nixosConfigurations);
    };
}
