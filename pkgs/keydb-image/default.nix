{
  dockerTools,
  keydb,
  cacert,
  bash,
  coreutils,
  findutils,
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
