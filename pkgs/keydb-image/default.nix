{
  dockerTools,
  keydb,
  cacert,
  ...
}:

dockerTools.buildLayeredImage {
  name = "keydb";
  tag = "latest";

  contents = [
    keydb
    cacert
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
