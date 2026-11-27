{ config, ... }:
{
  config = {
    # Matter needs IPv6 routes to Thread devices even with an external border router.
    networking.enableIPv6 = true;
    # Match per-node IPv6 firewall aliases instead of selecting rotating privacy addresses.
    networking.interfaces.${builtins.head config.libraryofalexandria.node.interfaces}.tempAddress = "disabled";
    boot.kernel.sysctl = {
      "net.ipv6.conf.all.disable_ipv6" = 0;
      "net.ipv6.conf.default.disable_ipv6" = 0;
      # Keep learning LAN routes when Kubernetes enables host forwarding.
      "net.ipv6.conf.all.accept_ra" = 2;
      "net.ipv6.conf.default.accept_ra" = 2;
      "net.ipv6.conf.${builtins.head config.libraryofalexandria.node.interfaces}.accept_ra" = 2;
      "net.ipv6.conf.all.accept_ra_rt_info_max_plen" = 64;
      "net.ipv6.conf.default.accept_ra_rt_info_max_plen" = 64;
      "net.ipv6.conf.${builtins.head config.libraryofalexandria.node.interfaces}.accept_ra_rt_info_max_plen" = 64;
    };
  };
}
