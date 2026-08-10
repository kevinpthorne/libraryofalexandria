{
  pkgs,
  dockerTools,
  bash,
  coreutils,
  asterisk,
  dectalk-asterisk,
  ffmpeg,
  unixODBC,
  unixODBCDrivers,
  postgresql,
  ...
}:

dockerTools.buildLayeredImage {
  name = "asterisk";
  tag = "latest";

  contents = [
    bash
    coreutils
    dockerTools.binSh
    asterisk
    dectalk-asterisk
    ffmpeg
    unixODBC
    unixODBCDrivers.psql
    postgresql
  ];

  config = {
    # Since we are using Nix's asterisk, it will be in the PATH
    Cmd = [ "asterisk" "-f" "-vvvddd" ];
    ExposedPorts = {
      "5060/udp" = {};
    };
  };
}
