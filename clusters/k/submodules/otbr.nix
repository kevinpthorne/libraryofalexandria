{ ... }:
{
  config = {
    # OTBR brokers use the host network and may follow the USB radio to any node.
    boot.kernelModules = [ "tun" "ip6table_filter" "ip_set_hash_net" "xt_set" "iptable_nat" ];
    boot.kernel.sysctl = {
      "net.ipv4.ip_forward" = 1;
      "net.ipv6.conf.all.forwarding" = 1;
      "net.ipv6.conf.default.forwarding" = 1;
    };
  };
}