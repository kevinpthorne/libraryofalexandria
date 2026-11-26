{ config, ... }:
{
  config = {
    # OTBR brokers use the host network and may follow the USB radio to any node.
    boot.kernelModules = [ "tun" "ip6table_filter" "ip_set_hash_net" "xt_set" "iptable_nat" ];
    boot.kernel.sysctl = {
      "net.ipv4.ip_forward" = 1;
      "net.ipv6.conf.all.disable_ipv6" = 0;
      "net.ipv6.conf.default.disable_ipv6" = 0;
      "net.ipv6.conf.all.forwarding" = 1;
      "net.ipv6.conf.default.forwarding" = 1;
      # Forwarding normally disables SLAAC/RA reception; OTBR still needs LAN RAs.
      "net.ipv6.conf.all.accept_ra" = 2;
      "net.ipv6.conf.default.accept_ra" = 2;
      "net.ipv6.conf.${builtins.head config.libraryofalexandria.node.interfaces}.accept_ra" = 2;
      "net.ipv6.conf.all.accept_ra_rt_info_max_plen" = 64;
      "net.ipv6.conf.default.accept_ra_rt_info_max_plen" = 64;
      "net.ipv6.conf.${builtins.head config.libraryofalexandria.node.interfaces}.accept_ra_rt_info_max_plen" = 64;
    };
  };
}