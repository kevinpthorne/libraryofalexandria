{
  lib,
  pkgs,
  config,
  lib2,
  ...
}:
let
  isMaster = config.libraryofalexandria.node.type == "master";
  masterIps = config.libraryofalexandria.node.masterIps;
  masterHostnameOf = id: with config.libraryofalexandria.node; lib2.getHostname "master" id clusterName;
  masterHostnames = builtins.map masterHostnameOf (
    lib2.range config.libraryofalexandria.cluster.masters.count
  );
  masterHostnamesAndIps = lib2.zipLists masterHostnames masterIps;
  haProxyBackendServersList = builtins.map (
    hostname:
    let
      physicalIp = masterHostnamesAndIps.${hostname};
      port = toString config.libraryofalexandria.node.masterPort;
    in
    "server ${hostname} ${physicalIp}:${port} check"
  ) masterHostnames;
  haProxyBackendServers = builtins.concatStringsSep "\n  " haProxyBackendServersList;
in
{
  options.libraryofalexandria.k8sApiVirtualIps = {
    haproxyPort = lib.mkOption {
      type = lib.types.port;
      default = 6444;
    };

    vip = lib.mkOption {
      type = lib.types.str;
      default = config.libraryofalexandria.cluster.virtualIps.k8sApiVip;
      description = "IPv4 address";
    };

    iface = lib.mkOption {
      type = lib.types.str;
      default = (builtins.elemAt config.libraryofalexandria.cluster.virtualIps.interfaces 0);
    };
  };

  config = lib.mkIf (config.libraryofalexandria.cluster.virtualIps.enable && isMaster) {
    # 1. Kernel Parameter (CRITICAL for HAProxy + Keepalived)
    # Allows HAProxy to start and bind to the VIP even if this node is currently the "BACKUP"
    boot.kernel.sysctl."net.ipv4.ip_nonlocal_bind" = 1;

    # 2. Keepalived Configuration (The VIP Manager)
    services.keepalived = {
      enable = true;
      vrrpInstances.k8s_api_vip = {
        interface = config.libraryofalexandria.k8sApiVirtualIps.iface;
        virtualRouterId = config.libraryofalexandria.cluster.id;

        # NODE 1: Set state = "MASTER", priority = 100 for master0
        # NODE 2: Set state = "BACKUP", priority = 90 for master1
        # NODE 3: Set state = "BACKUP", priority = 80 for master2
        # ...
        # priority = max - (id * (max/count))
        state = if config.libraryofalexandria.node.id == 0 then "MASTER" else "BACKUP";
        priority =
          100
          - (config.libraryofalexandria.node.id * (100 / config.libraryofalexandria.cluster.masters.count));

        virtualIps = [
          {
            addr = config.libraryofalexandria.k8sApiVirtualIps.vip; # The highly available VIP
          }
        ];
      };
    };

    # Allow VRRP traffic (Protocol 112) through the NixOS firewall so nodes can elect a master
    networking.firewall.extraCommands = ''
      iptables -A INPUT -p vrrp -j ACCEPT
    '';

    # 3. HAProxy Configuration (The API Load Balancer)
    services.haproxy = {
      enable = true;
      config = ''
        global
          log /dev/log local0
          maxconn 4000
          user haproxy
          group haproxy

        defaults
          mode tcp
          log global
          option tcplog
          retries 3
          timeout queue 1m
          timeout connect 10s
          
          # CRITICAL: Long timeouts needed for k8s 'watch' requests
          timeout client 4h 
          timeout server 4h 

        frontend k8s_api_frontend
          # Bind strictly to the VIP on port 6444
          bind ${config.libraryofalexandria.k8sApiVirtualIps.vip}:${toString config.libraryofalexandria.k8sApiVirtualIps.haproxyPort}
          default_backend k8s_api_backend

        backend k8s_api_backend
          balance roundrobin
          option ssl-hello-chk
          
          # server <hostname> <ip>:<port> check
          ${haProxyBackendServers}
      '';
    };

    # 4. Open the HAProxy port so Cilium and worker nodes can connect
    networking.firewall.allowedTCPPorts = [ config.libraryofalexandria.k8sApiVirtualIps.haproxyPort ];
  };
}
