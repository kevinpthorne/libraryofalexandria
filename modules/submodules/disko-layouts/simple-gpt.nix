{
  disko.devices = {
    disk = {
      main = {
        type = "disk";
        content = {
          type = "gpt";
          partitions = {
            # Firmware / Boot Partition
            boot = {
              type = "0700"; # Standard FAT32 data partition
              size = "500M";
              content = {
                type = "filesystem";
                format = "vfat";
                mountpoint = "/boot";
                # Essential for Pi firmware to read the files without permission issues
                mountOptions = [ "fmask=0022" "dmask=0022" ]; 
              };
            };
            
            # Root filesystem
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
}