{
  config,
  lib,
  inputs,
  lib2,
  localPkgs,
  ...
}:
{
  imports = [
    ./masters.nix
    ./workers.nix
  ];

  options = {
    libraryofalexandria.cluster = {
      name = lib.mkOption {
        type = lib.types.str;
      };
      id = lib.mkOption {
        type = lib.types.ints.between 1 127;
        description = "Used for both cluster CIDR, service CIDR and clustermesh ID";
      };

      k8sEngine = lib.mkOption {
        type = lib.types.enum [
          "rke2"
          "kubernetes"
        ];
        default = "rke2";
      };

      deploymentMethod = lib.mkOption {
        type = lib.types.enum [
          "colmena"
          "deploy-rs"
          "manual"
        ];
        default = "colmena";
      };

      masters = lib.mkOption {
        type = lib.types.submodule (import ./masters.nix); # ??
      };

      workers = lib.mkOption {
        type = lib.types.submodule (import ./workers.nix);
      };

      apps = lib.mkOption {
        type = lib.types.attrsOf (lib.types.submodule ../modules/submodules/k8s/apps/_submodule.nix);
        description = "ArgoCD app configs, usually placed in master0's config";
      };

      virtualIps =
        let
          range = lib.types.submodule {
            options = {
              start = lib.mkOption {
                type = lib.types.str;
              };
              stop = lib.mkOption {
                type = lib.types.str;
              };
            };
          };
          cidr = lib.types.submodule {
            options = {
              cidr = lib.mkOption {
                type = lib.types.str;
              };
            };
          };
        in
        lib.mkOption {
          type = lib.types.submodule {
            options = {
              enable = lib.mkEnableOption "Set a virtual IP range for Cilium and Master HAProxy";

              k8sApiVip = lib.mkOption {
                type = lib.types.str;
                description = "IPv4 address for the k8s API HAProxy";
              };
              blocks = lib.mkOption {
                type = lib.types.listOf (lib.types.either range cidr);
              };
              interfaces = lib.mkOption {
                type = lib.types.listOf lib.types.str;
                default = [ "eth0" ];
              };
            };
          };
        };
    };
    # rendered options, never given outside this module
    # TODO remove this pattern, it sucks
    masters = lib.mkOption {
      readOnly = true;
    };
    workers = lib.mkOption {
      readOnly = true;
    };
    nodes = lib.mkOption {
      readOnly = true;
    };
    nixosConfigurations = lib.mkOption {
      readOnly = true;
    };
    modules = lib.mkOption {
      readOnly = true;
    };
    colmena = lib.mkOption {
      # readOnly = true;
    };
    deploy-rs = lib.mkOption {
      # readOnly = true;
    };
    packages = lib.mkOption {
      readOnly = true;
    };
  };

  config =
    let
      # TODO why didn't lib.asserts.assertMsg work here?
      _ =
        config.libraryofalexandria.cluster.masters.count != 2
        || builtins.throw "Cannot have 2 master nodes for etcd. There must be 1 or 3+";

      # Testing requires using modules directly, instead of a nixosSystem
      getNixosMegaModule =
        nodeType: nodeId:
        { ... }:
        {
          imports = [
            (lib2.importIfExistsArgs ./_defaults/node.nix (
              with config.libraryofalexandria; { inherit cluster nodeId; }
            ))
            (lib2.importIfExistsArgs ./_defaults/${nodeType}.nix (
              with config.libraryofalexandria; { inherit cluster nodeId; }
            ))
            (lib2.importIfExistsArgs ./_defaults/${nodeType}-${toString nodeId}.nix (
              with config.libraryofalexandria; { inherit cluster nodeId; }
            ))
          ]
          ++ (config.libraryofalexandria.cluster."${nodeType}s".modules nodeId);

          nixpkgs.overlays = [ localPkgs ];
        };
      wrapNixosModule = name: megaModule: {
        name = megaModule;
      };
      systemSpecialArgs =
        nodeId: with config.libraryofalexandria; {
          inherit inputs;
          inherit lib2;
          inherit cluster;
          inherit nodeId;
        };

      # For building (flake nixosConfigurations), we'll stack everything as nixosSystems
      getNixosSystem =
        nodeId: nodeModule:
        lib.nixosSystem {
          modules = [ nodeModule ];
          extraModules = [ inputs.colmena.nixosModules.deploymentOptions ];
          specialArgs = systemSpecialArgs nodeId;
        };
      wrapNixosSystem = nixosSystem: {
        "${nixosSystem.config.libraryofalexandria.node.hostname}" = nixosSystem;
      };
      getMasterMegaModule = nodeId: getNixosMegaModule "master" nodeId;
      getMasterSystem = nodeId: getNixosSystem nodeId (getMasterMegaModule nodeId);
      getWorkerMegaModule = nodeId: getNixosMegaModule "worker" nodeId;
      getWorkerSystem = nodeId: getNixosSystem nodeId (getWorkerMegaModule nodeId);
      masterIds = lib2.range config.libraryofalexandria.cluster.masters.count; # [ 0, 1, ...]
      workerIds = lib2.range config.libraryofalexandria.cluster.workers.count;

      masterSystems = builtins.map (id: getMasterSystem id) masterIds;
      workerSystems = builtins.map (id: getWorkerSystem id) workerIds;
      allSystems = masterSystems ++ workerSystems;

      collectSystems =
        systemsList:
        builtins.foldl' (otherSystemsSet: systemSet: otherSystemsSet // systemSet) { } (
          builtins.map (system: wrapNixosSystem system) systemsList
        );

      masterModulesAttrSets = builtins.map (
        id:
        let
          moduleName = "master${id}";
          module = getMasterMegaModule id;
          moduleAsAttrSet = wrapNixosModule moduleName module;
        in
        moduleAsAttrSet
      ) masterIds;
      workerModulesAttrSets = builtins.map (
        id:
        let
          moduleName = "worker${id}";
          module = getWorkerMegaModule id;
          moduleAsAttrSet = wrapNixosModule moduleName module;
        in
        moduleAsAttrSet
      ) workerIds;
      collectModules =
        modulesAttrsetList:
        builtins.foldl' (
          otherModulesSet: moduleAttrSet: otherModulesSet // moduleAttrSet
        ) { } modulesAttrsetList;

      collectAll = attrGenerator: builtins.foldl' (acc: id: acc // attrGenerator id) { };

      systemBuilder = system: system.config.system.builder.package; # defined by imageable
      allSystemsBuilder =
        pkgs:
        let
          clusterName = config.libraryofalexandria.cluster.name;
          derivations = builtins.map (system: systemBuilder system) allSystems;
          concatCommands = commands: builtins.concatStringsSep "\n" commands;
        in
        pkgs.stdenv.mkDerivation {
          name = "build-all-${clusterName}";
          src = ./.;

          buildInputs = derivations;

          buildPhase = ''
            set -x
            # Make directories
            ${concatCommands (
              builtins.map (
                system: "mkdir -p $out/images/${system.config.libraryofalexandria.node.hostname}/"
              ) allSystems
            )}

            ${concatCommands (
              builtins.map (
                system:
                "ln -s -t $out/images/${system.config.libraryofalexandria.node.hostname}/ ${system.config.system.builder.package}/${system.config.system.builder.outputDir}/*"
              ) allSystems
            )}

            echo "All systems of cluster ${clusterName} available in $out/images/ (i.e. result/images/)"
          '';
        };
    in
    {
      libraryofalexandria.cluster.apps = {
        loa-core = {
          repo = lib.mkDefault "https://github.com/kevinpthorne/libraryofalexandria.git";
          subPath = lib.mkDefault "apps/loa-core";
        };
        loa-federation = {
          repo = lib.mkDefault "https://github.com/kevinpthorne/libraryofalexandria.git";
          subPath = lib.mkDefault "apps/loa-federation";
        };
        loa-observability = {
          repo = lib.mkDefault "https://github.com/kevinpthorne/libraryofalexandria.git";
          subPath = lib.mkDefault "apps/loa-observability";
        };
        "${config.libraryofalexandria.cluster.name}-apps" = {
          repo = lib.mkDefault "https://github.com/kevinpthorne/libraryofalexandria.git";
          subPath = lib.mkDefault "apps/${config.libraryofalexandria.cluster.name}-apps";
        };
      };

      # masters = collectAll (id: wrapNixosSystem id) masterSystems;
      masters = collectSystems masterSystems;
      # masters
      # ..master0
      # ..master1
      workers = collectSystems workerSystems;
      # workers
      # ..worker0
      # ..worker1
      # nodes = masters // workers
      nodes = config.masters // config.workers;
      #
      # nixosConfigurations = nodes
      nixosConfigurations = config.nodes;
      # modules-only, for nixosTest
      modules = (collectModules masterModulesAttrSets) // (collectModules workerModulesAttrSets);
      # deploy-rs
      deploy-rs = lib.mkIf (config.libraryofalexandria.cluster.deploymentMethod == "deploy-rs") {
        nodes = builtins.mapAttrs (name: value: {
          hostname = value.config.libraryofalexandria.node.deployment.deploy-rs.hostName;
          profiles.system = {
            user = "root";
            sshUser = value.config.libraryofalexandria.node.deployment.deploy-rs.userName;
            sshOpts = [
              "-A"
              "-p"
              (toString value.config.libraryofalexandria.node.deployment.deploy-rs.port)
              # "-i" "~/.ssh/deployment"
              # "-o" "StrictHostKeyChecking=no"
            ];
            path = inputs.deploy-rs.lib.${value.config.nixpkgs.hostPlatform.system}.activate.nixos value;
          };
        }) (config.nodes);
      };
      # colmena
      colmena =
        if (config.libraryofalexandria.cluster.deploymentMethod == "colmena") then
          (
            {
              meta = {
                nixpkgs = import inputs.nixpkgs {
                  system = "aarch64-linux"; # FIXME this will cause issues on x86 builder hosts
                  # hostPlatform = "aarch64-linux";
                };
                nodeNixpkgs = builtins.mapAttrs (_: v: v.pkgs) config.nodes;
                nodeSpecialArgs = builtins.mapAttrs (_: v: v._module.specialArgs) config.nodes;
                specialArgs = {
                  inherit lib;
                  inherit inputs;
                  inherit lib2;
                };
              };
            }
            // builtins.mapAttrs (name: value: {
              nixpkgs.hostPlatform = "aarch64-linux"; # value.config.nixpkgs.hostPlatform.system;
              imports = [
                (
                  if value.config.libraryofalexandria.node.type == "master" then
                    getMasterMegaModule value.config.libraryofalexandria.node.id
                  else
                    getWorkerMegaModule value.config.libraryofalexandria.node.id
                )
              ];
            }) (config.nodes)
          )
        else
          { };
      # packages
      # ..build-all-${clusterName}
      packages = lib2.eachArch (
        arch:
        let
          pkgs = import inputs.nixpkgs {
            hostPlatform = arch;
            system = arch;
            overlays = [ localPkgs ];
          };
        in
        {
          "build-all-${config.libraryofalexandria.cluster.name}" = allSystemsBuilder pkgs; # TODO this technically names the package twice - why not once?
          "chart-index-${config.libraryofalexandria.cluster.name}" =
            (builtins.head masterSystems).config.system.build.chartIndex;
          # "go-archs-${config.libraryofalexandria.cluster.name}" = pkgs.go-arch-index.override {
          #     inherit pkgs;
          #     inherit lib;
          #     clusterName = config.libraryofalexandria.cluster.name;
          #     nixosConfigurations = config.nodes;
          # };
        }
      );
    };
}
