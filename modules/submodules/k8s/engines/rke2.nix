{
  config,
  pkgs,
  lib,
  lib2,
  ...
}:
let
  haProxyRke2Port = "9345";  # rke2 hardcodes this port ugh
in
{
  imports = [
    ./rke2
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
      isClusterFederated = cluster: cluster.federateTo == [ ];
      isThisClusterFederated = isClusterFederated thisCluster;
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
                rke2-overrides-helm
                cilium-keys-gen-helm
              ]
            else
              [ ]
          );
      };

      services.rke2 =
        let
          tlsSanFlags = builtins.map (ip: "--tls-san=${ip}") (
            config.libraryofalexandria.node.masterIps
            ++ (
              if thisCluster.virtualIps.enable then [ config.libraryofalexandria.k8sApiVirtualIps.vip ] else [ ]
            )
          );

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
                parameters = ". ${peerCluster.dnsIp}";
              }
              { name = "loop"; }
              { name = "reload"; }
              { name = "loadbalance"; }
            ];
          }) thisCluster.federation.peers;
        in
        {
          enable = true;
          serverAddr =
            if isMaster0 then
              ""  # master0 is bootstrap node
            else if thisCluster.virtualIps.enable then
              "https://${config.libraryofalexandria.k8sApiVirtualIps.vip}:${haProxyRke2Port}"
            else
              "https://${master0Ip}:9345"; # default rke2 port
        }
        // (
          if isMaster then
            {
              role = "server";
              cni = "cilium";
              nodeIP = thisMasterIp;
              tokenFile = "/var/keys/token.key"; # match rke2/deployment.nix
              agentTokenFile = "/var/keys/agent-token.key"; # match rke2/deployment.nix
              extraFlags = [
                "--profile=cis"
                "--disable-kube-proxy" # cilium to do
                "--cluster-cidr=${thisCluster.clusterCidr}"
                "--service-cidr=${thisCluster.serviceCidr}"
                "--bind-address=${thisMasterIp}"
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
                      type = "wireguard";
                    };
                    MTU = if isThisClusterFederated then 1200 else 0; # double tunnel breaks
                    dnsProxy.enableTransparentMode = true;
                    l2announcements.enabled = thisCluster.virtualIps.enable;
                    externalIPs.enabled = thisCluster.virtualIps.enable;
                    gatewayAPI.enabled = true;
                    bgpControlPlane.enabled = true;
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
              tokenFile = "/var/keys/agent-token.key";
              extraFlags = [
                "--profile=cis"
              ];
            }
        );

      # load balance rke2 service
      services.haproxy = lib.mkIf (thisCluster.virtualIps.enable && isMaster) {
        config =
          let
            # TODO dedupe this code with kube-api-vips
            masterIps = config.libraryofalexandria.node.masterIps;
            masterHostnameOf =
              id: with config.libraryofalexandria.node; lib2.getHostname "master" id clusterName;
            masterHostnames = builtins.map masterHostnameOf (
              lib2.range config.libraryofalexandria.cluster.masters.count
            );
            master0Name = with config.libraryofalexandria.node; lib2.getHostname "master" 0 clusterName;
            masterHostnamesAndIps = lib2.zipLists masterHostnames masterIps;
            haProxyBackendServersList = builtins.map (
              hostname:
              let
                physicalIp = masterHostnamesAndIps.${hostname};
                port = "9345"; # rke2 default port
              in
              "server ${hostname} ${physicalIp}:${port} check ${if hostname == master0Name then "" else "backup"}"
            ) masterHostnames;
            haProxyBackendServers = builtins.concatStringsSep "\n  " haProxyBackendServersList;
            # let k8s api module define defaults
          in
          lib.mkAfter ''
            frontend rke2_api_frontend
              bind ${config.libraryofalexandria.k8sApiVirtualIps.vip}:${haProxyRke2Port}
              default_backend rke2_api_backend

            backend rke2_api_backend
              option ssl-hello-chk
              
              # server <hostname> <ip>:<port> check
              ${haProxyBackendServers}
          '';
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
        {
          name = "cilium-bgp-peering-policies";
          chart = "${pkgs.cilium-bgp-peering-policies}/cilium-bgp-peering-policies-0.1.0.tgz";
          values = {
            policies = [
              {
                name = "edgevpn-peering";
                localASN = 65000;
                exportPodCIDR = false;
                nodeSelector = {};
                neighbors = [
                  {
                    peerAddress = "${thisCluster.federationBorderRouterIp}/32";
                    peerASN = thisCluster.localAS;
                  }
                ];
              }
            ];
          };
          namespace = "kube-system";
        }
      ];
    };
}
