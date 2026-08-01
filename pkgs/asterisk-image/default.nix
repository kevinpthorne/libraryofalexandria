{
  dockerTools,
  bash,
  coreutils,
  ...
}:

dockerTools.buildLayeredImage {
  name = "asterisk";
  tag = "latest";

  contents = [
    bash
    coreutils
    dockerTools.binSh
  ];

  config = {
    Cmd = [ "/usr/sbin/asterisk" "-f" "-vvvddd" ];
    ExposedPorts = {
      "5060/udp" = {};
    };
  };
}
