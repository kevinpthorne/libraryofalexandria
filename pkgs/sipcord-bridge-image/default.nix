{
  dockerTools,
  sipcord-bridge,
  cacert,
  bash,
  coreutils,
  ...
}:

dockerTools.buildLayeredImage {
  name = "sipcord-bridge";
  tag = "latest";

  contents = [
    sipcord-bridge
    cacert
    bash
    coreutils
    dockerTools.binSh
  ];

  config = {
    Cmd = [ "sipcord-bridge" ];
    WorkingDir = "/app";
    ExposedPorts = {
      "5060/udp" = {};
      "5060/tcp" = {};
    };
    Env = [
      "DIALPLAN_PATH=/app/dialplan.toml"
      "SIP_PORT=5060"
      "RTP_PORT_START=10000"
      "RTP_PORT_END=15000"
    ];
  };
}
