{
  config,
  pkgs,
  lib,
  ...
}:
{
  imports = [
    ../../nixstore-linker.nix
    ../helm
  ];

  config =
    let
      thisCluster = config.libraryofalexandria.cluster;
      isMaster = config.libraryofalexandria.node.type == "master";
      isWorker = !isMaster;
      isMaster0 = isMaster && config.libraryofalexandria.node.id == 0;
      master0Ip = builtins.elemAt config.libraryofalexandria.node.masterIps 0;
      thisMasterIp =
        if isWorker then
          ""
        else
          builtins.elemAt config.libraryofalexandria.node.masterIps config.libraryofalexandria.node.id;
    in
    lib.mkIf (thisCluster.k8sEngine == "rke2") {
      environment = {
        etc."crictl.yaml".text = ''
          runtime-endpoint: unix:///run/k3s/containerd/containerd.sock
          image-endpoint: unix:///run/k3s/containerd/containerd.sock
          timeout: 10
          debug: false
        '';
        variables = lib.mkIf isMaster {
          "KUBECONFIG" = "/etc/rancher/rke2/rke2.yaml"; # must match helm chart installer
        };
        systemPackages =
          with pkgs;
          [
            rke2
            cri-tools
            rke2-images
            rke2-images-cilium
          ]
          ++ (
            if isMaster then
              [
                kompose
                kubectl
                k9s
                argocd
                argocd-vault-plugin
                jq
                yq
              ]
            else
              [ ]
          )
          ++ (
            if isMaster0 then
              [
                rke2-overrides-helm
                cilium-keys-gen-helm
              ]
            else
              [ ]
          );
      };

      deployment.keys = {
        "token.key" = lib.mkIf isMaster {
          keyFile = "/var/keys/clusters/${thisCluster.name}/token.key";
          destDir = "/var/keys";
          permissions = "0600";
          uploadAt = "pre-activation";
        };
        "agent-token.key" = lib.mkIf isWorker {
          keyFile = "/var/keys/clusters/${thisCluster.name}/agent-token.key";
          destDir = "/var/keys";
          permissions = "0600";
          uploadAt = "pre-activation";
        };
      };

      services.nixstore-linker = {
        # https://docs.rke2.io/install/airgap?airgap-load-images=Manually+Deploy+Images&airgap-upgrade=Manual+Upgrade&installation-methods=Script+install#1-load-images
        rke2-images = {
          targetPackage = pkgs.rke2-images;
          targetPackageSubpath = "asset/rke2-images";
          linkPath = "/var/lib/rancher/rke2/agent/images/";
          ensureDirectories = [ "/var/lib/rancher/rke2/agent/images/" ];
        };
        rke2-images-cilium = {
          targetPackage = pkgs.rke2-images-cilium;
          targetPackageSubpath = "asset/rke2-images-cilium";
          linkPath = "/var/lib/rancher/rke2/agent/images/";
          ensureDirectories = [ "/var/lib/rancher/rke2/agent/images/" ];
        };
      };

      # k8s protect kernel
      # vm.overcommit_memory=1
      # kernel.panic=10
      # kernel.panic_on_oops=1
      # already set in 25.11
      # boot.kernelParams = [
      #     "panic_on_oops=1"
      #     "panic=10"
      # ];
      # boot.kernel.sysctl = {
      #     "vm.overcommit_memory" = 1;
      #     "kernel.panic_on_oops" = 1;
      #     "kernel.panic" = 10;
      # };

      services.rke2 =
        let
          tlsSanFlags = builtins.map (ip: "--tls-san=${ip}") (
            config.libraryofalexandria.node.masterIps
            ++ (
              if thisCluster.virtualIps.enable then [ config.libraryofalexandria.k8sApiVirtualIps.vip ] else [ ]
            )
          );
          clusterCidrOf = cluster: "10.${toString cluster.id}.0.0/16";
          serviceCidrOf = cluster: "10.${toString (cluster.id + 127)}.0.0/16";
          dnsIpOf = cluster: "10.${toString (cluster.id + 127)}.0.10";

          federatedServers = lib.mapAttrsToList (clusterName: peerCluster: {
            zones = [
              {
                zone = "cluster.${peerCluster.name}.";
                use_tcp = true;
              }
            ];
            port = 53;
            plugins = [
              { name = "errors"; }
              {
                name = "cache";
                parameters = 30;
              }
              {
                name = "forward";
                parameters = ". ${dnsIpOf peerCluster}";
              }
              { name = "loop"; }
              { name = "reload"; }
              { name = "loadbalance"; }
            ];
          }) thisCluster.federation;
        in
        {
          enable = true;
          serverAddr = if isMaster0 then "" else "https://${master0Ip}:9345"; # default rke2 port
        }
        // (
          if isMaster then
            {
              role = "server";
              cni = "cilium";
              nodeIP = thisMasterIp;
              tokenFile = "/var/keys/token.key";
              extraFlags = [
                "--profile=cis"
                "--disable-kube-proxy" # cilium to do
                "--cluster-cidr=${clusterCidrOf thisCluster}"
                "--service-cidr=${serviceCidrOf thisCluster}"
                # do not set cluster domain here, set it in the coredns overrides below
              ]
              ++ tlsSanFlags;
              disable = [
                "rke2-ingress-nginx"
                "rke2-servicelb"
              ];
              manifests = lib.mkIf isMaster {
                "rke2-cilium-config".content = {
                  apiVersion = "helm.cattle.io/v1";
                  kind = "HelmChartConfig";
                  metadata = {
                    name = "rke2-cilium";
                    namespace = "kube-system";
                  };
                  spec.valuesContent = builtins.toJSON {
                    cluster = {
                      name = thisCluster.name;
                      id = thisCluster.id;
                    };
                    clustermesh = {
                      useAPIServer = true;
                      enabled = true;
                      config.enabled = true;
                      service.type = if thisCluster.virtualIps.enable then "LoadBalancer" else "NodePort";
                    };
                    encryption = {
                      enabled = true;
                      type = "ipsec";
                      ipsec.secretName = "cilium-ipsec-keys";
                    };
                    dnsProxy.enableTransparentMode = true;
                    l2announcements.enabled = thisCluster.virtualIps.enable;
                    externalIPs.enabled = thisCluster.virtualIps.enable;
                    gatewayAPI.enabled = true;
                    localRedirectPolicies.enabled = true;
                    kubeProxyReplacement = true;
                    k8sServiceHost =
                      if thisCluster.virtualIps.enable then
                        config.libraryofalexandria.k8sApiVirtualIps.vip
                      else
                        "127.0.0.1";
                    k8sServicePort =
                      if thisCluster.virtualIps.enable then
                        config.libraryofalexandria.k8sApiVirtualIps.haproxyPort
                      else
                        config.libraryofalexandria.node.masterPort;
                    hubble = {
                      enabled = true;
                      relay.enabled = true;
                      ui.enabled = true;
                    };
                  };
                };
                "rke2-coredns-config".content = {
                  apiVersion = "helm.cattle.io/v1";
                  kind = "HelmChartConfig";
                  metadata = {
                    name = "rke2-coredns";
                    namespace = "kube-system";
                  };
                  spec.valuesContent = builtins.toJSON {
                    nodelocal.enabled = true;
                    # nodelocal.use_cilium_lrp = true;
                    servers = federatedServers ++ [
                      {
                        zones = [
                          {
                            zone = ".";
                            use_tcp = true;
                          }
                        ];
                        port = 53;
                        plugins = [
                          {
                            name = "errors";
                          }
                          {
                            name = "health";
                            configBlock = ''
                              lameduck 10s
                            '';
                          }
                          {
                            name = "ready";
                          }
                          {
                            name = "rewrite";
                            parameters = "stop name suffix cluster.${thisCluster.name} .cluster.local";
                          }
                          {
                            name = "kubernetes";
                            parameters = "cluster.local in-addr.arpa ip6.arpa";
                          }
                          {
                            name = "forward";
                            parameters = ". /etc/resolv.conf";
                          }
                          {
                            name = "cache";
                            parameters = 30;
                          }
                          {
                            name = "loop";
                          }
                          {
                            name = "reload";
                          }
                          {
                            name = "loadbalance";
                          }
                        ];
                      }
                    ];
                  };
                };
              };
              # supposedly autoDeployCharts can deploy a local chart?
              charts = lib.mkIf isMaster (
                let
                  localChartModules = builtins.filter (
                    chart: chart.isLocalChart
                  ) config.libraryofalexandria.helmCharts.charts;
                  localCharts = builtins.listToAttrs (
                    builtins.map (chart: {
                      name = chart.name;
                      value = chart.chart;
                    }) localChartModules
                  );
                in
                localCharts
              );
              autoDeployCharts = lib.mkIf isMaster (
                let
                  chartToAttrs = chart: {
                    name = chart.name;
                    value = {
                      package = chart.chartPackage;
                      values = chart.values;
                      targetNamespace = if chart.namespace == null then "default" else chart.namespace;
                      createNamespace = true;
                    };
                  };
                  charts = builtins.listToAttrs (
                    builtins.map chartToAttrs config.libraryofalexandria.helmCharts.charts
                  );
                in
                charts
              );
            }
          else
            {
              role = "agent";
              agentTokenFile = "/var/keys/agent-token.key";
              extraFlags = [
                "--profile=cis"
                "--disable-kube-proxy"
              ]
              ++ tlsSanFlags;
            }
        );

      systemd.services.rke2-server = {
        unitConfig = {
          # The service will stay in 'inactive' state until this file exists
          AssertPathExists = if isMaster then "/var/keys/token.key" else "/var/keys/agent-token.key";
        };
      };

      # etcd hardening
      users =
        if isMaster then
          {
            groups.etcd = { }; # create an 'etcd' group

            users.etcd = {
              isSystemUser = true;
              description = "etcd service user";
              group = "etcd";
              home = "/var/lib/etcd"; # optional, standard for etcd
              createHome = true; # ensures directory exists
            };
          }
        else
          { };

      # cilium hardening
      libraryofalexandria.helmCharts.enable = true;
      libraryofalexandria.helmCharts.installerEnabled = lib.mkForce false;
      libraryofalexandria.helmCharts.charts = lib.mkBefore [
        {
          name = "gateway-api-crds";
          chart = "${pkgs.gateway-api-crds-helm}/gateway-api-crds-helm-0.1.0.tgz";
          namespace = "kube-system";
          _ensureOnce = true;
        }
        {
          name = "cilium-keys-gen-helm";
          chart = "${pkgs.cilium-keys-gen-helm}/cilium-keys-gen-helm-0.1.0.tgz";
          namespace = "kube-system";
          _ensureOnce = true;
        }
        (lib.mkIf thisCluster.virtualIps.enable {
          name = "cilium-virtual-ips";
          chart = "${pkgs.cilium-virtual-ips}/cilium-virtual-ips-0.1.0.tgz";
          values = {
            blocks = thisCluster.virtualIps.blocks;
            interfaces = thisCluster.virtualIps.interfaces;
          };
          namespace = "kube-system";
        })
      ];
    };
}
