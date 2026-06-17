{
  dockerTools,
  keydb,
  cacert,
  bash,
  coreutils,
  findutils,
  hostname,
  ...
}:

dockerTools.buildLayeredImage {
  name = "keydb";
  tag = "latest";

  contents = [
    keydb
    cacert
    bash
    coreutils
    findutils
    hostname
    dockerTools.binSh
  ];

  config = {
    Cmd = [ "keydb-server" ];
    ExposedPorts = {
      "6379/tcp" = {};
    };
    WorkingDir = "/data";
    Volumes = {
      "/data" = {};
    };
  };
}
