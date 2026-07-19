{
  dockerTools,
  rtpengine,
  bash,
  coreutils,
  ...
}:

dockerTools.buildLayeredImage {
  name = "rtpengine";
  tag = "latest";

  contents = [
    rtpengine
    bash
    coreutils
    dockerTools.binSh
  ];

  config = {
    Cmd = [ "rtpengine" "--foreground" "--config-file=/etc/rtpengine/rtpengine.conf" ];
    ExposedPorts = {
      "22222/udp" = {};
    };
  };
}
