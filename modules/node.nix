{
  config,
  pkgs,
  lib,
  lib2,
  ...
}:
let
  indexOf = val: lib.lists.findFirstIndex (x: x == val) null;
in
{
  imports = [
    ./submodules/deployment
    ./submodules/k8s
  ];

  options.libraryofalexandria.node = {
    enable = lib.mkEnableOption "Make this NixOS configuration a node ready for being in a LoA cluster";

    type = lib.mkOption {
      default = "worker";
      type = lib.types.enum [
        "master"
        "worker"
      ];
      description = "Defines if this node is a master or worker";
    };

    id = lib.mkOption {
      type = lib.types.ints.unsigned;
    };

    clusterName = lib.mkOption {
      type = lib.types.str;
    };

    hostname = lib.mkOption {
      type = lib.types.str;
      default = with config.libraryofalexandria.node; lib2.getHostname type id clusterName; # e.g. worker0-k
    };

    masterIps = lib.mkOption {
      type = lib.types.listOf lib.types.str; # TODO should be a set
      description = "IP of masters (in order)";
    };

    masterPort = lib.mkOption {
      type = lib.types.port;
      default = 6443;
    };
  };

  options.libraryofalexandria.cluster = lib.mkOption {
    type = lib.types.attrs;
  };

  config =
    let
      isMaster = config.libraryofalexandria.node.type == "master";
      isWorker = !isMaster;
      # Master IP to String
      masterIpsToHostnames =
        with config.libraryofalexandria.node;
        builtins.listToAttrs (
          builtins.map (ip: {
            name = ip;
            value = lib2.getHostname "master" (indexOf ip masterIps) clusterName;
          }) masterIps
        );
      extraHostEntries = map (entry: "${entry.name} ${entry.value}") (
        lib.attrsets.attrsToList masterIpsToHostnames
      );
      extraHostsStr = lib.concatStringsSep "\n" extraHostEntries;
    in
    lib.mkIf config.libraryofalexandria.node.enable {

      libraryofalexandria.zarf.enable = false;

      networking = {
        hostName = config.libraryofalexandria.node.hostname;
        hostId = with config.libraryofalexandria; lib2.getHostId cluster node;
        extraHosts = extraHostsStr;
        firewall.enable = false;
        # firewall done by cilium
        # firewall = lib.mkIf isMaster {
        #     enable = true;
        #     allowedTCPPorts = [ 8888 config.libraryofalexandria.node.masterPort ];
        # };
        # TODO maybe set ip statically?
        enableIPv6 = true; # Enabled to support OTBR IPv6 routing; prioritized IPv4 via gai.conf below
      };
      system.nixos.label = config.libraryofalexandria.node.hostname;

      environment = {
        systemPackages = with pkgs; [
          vim
          curl
          htop
          tcptraceroute
          tcpdump
        ];
      };

      # show IP on login screen
      environment.etc."issue.d/ip.issue".text = "\\4\n";

      # Prioritize IPv4 over IPv6 for system resolution (RFC 6724)
      environment.etc."gai.conf".text = ''
        precedence  ::1/128       50
        precedence  ::/0          40
        precedence  ::ffff:0:0/96 100
      '';
      networking.dhcpcd.runHook = "${pkgs.util-linux}/bin/agetty --reload";

      nix.settings = {
        experimental-features = [
          "nix-command"
          "flakes"
        ];
        trusted-users = [ "root" ];
      };

      # Use chrony and USNO servers for NTP
      services.timesyncd.enable = false;
      services.chrony = {
        enable = true;
        # Use the US Naval Observatory (USNO) NTP servers
        servers = [
          "tick.usno.navy.mil"
          "tock.usno.navy.mil"
        ];
        # for faster synchronization on startup
        serverOption = "iburst";
      };

      users.motd = "=== LoA Cluster ${config.libraryofalexandria.cluster.name} ===";
      services.openssh.settings.PrintMotd = true;

      system.stateVersion = "25.11";
    };
}
