nodeConfig:
{ pkgs, lib, ... }:
{
  config = {
    users.users.root.initialPassword = "root";
    networking = {
      useDHCP = false;
      interfaces = {
        wlan0.useDHCP = false;
        eth0.useDHCP = true;
      };
    };
    raspberry-pi-nix.board = "bcm2712"; # pi 5
    security.rtkit.enable = true;

    # required for kubernetes on rpi
    boot.kernelParams = [
      "cgroup_enable=cpuset"
      "cgroup_enable=memory"
      "cgroup_memory=1"
    ];

    systemd.services.etcd = {
      environment = {
        ETCD_UNSUPPORTED_ARCH = "arm64";
      };
    };
    services.kubernetes = {
      addons.dns = {
        enable = true;
        coredns = {
          finalImageTag = "1.10.1";
          imageDigest = "sha256:a0ead06651cf580044aeb0a0feba63591858fb2e43ade8c9dea45a6a89ae7e5e";
          imageName = "coredns/coredns";
          sha256 = "0c4vdbklgjrzi6qc5020dvi8x3mayq4li09rrq2w0hcjdljj0yf9";
        };
      };
    };
  };
}
