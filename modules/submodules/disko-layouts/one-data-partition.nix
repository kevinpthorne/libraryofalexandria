{
  disko.devices = {
    disk = {
      data = {
        type = "disk";
        content = {
          type = "gpt";
          partitions = {
            root = {
              size = "100%";
              content = {
                type = "filesystem";
                format = "ext4";
                mountpoint = "/var";
              };
            };
          };
        };
      };
    };
  };
}