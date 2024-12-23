nodeConfig:
{ pkgs, lib, ... }:
{
  config = {
    disko.devices = {
        disk = {
            main = {
                device = "/dev/sda";
                type = "disk";
                content = {
                    type = "gpt";
                    partitions = {
                        MBR = {
                            type = "EF02"; # for grub MBR
                            size = "1M";
                        };
                        ESP = {
                            type = "EF00";
                            size = "500M";
                            content = {
                                type = "filesystem";
                                format = "vfat";
                                mountpoint = "/boot";
                            };
                        };
                        root = {
                            size = "100%";
                            content = {
                                type = "filesystem";
                                format = "ext4";
                                mountpoint = "/";
                            };
                        };
                    };
                };
            };
        };
    };
  };
}