{
  config,
  lib,
  ...
}:
let
  thisCluster = config.libraryofalexandria.cluster;
  isMaster = config.libraryofalexandria.node.type == "master";
in
{
  config = {
    deployment.keys = {
      "token.key" = lib.mkIf isMaster {
        keyFile = "/var/keys/clusters/${thisCluster.name}/token.key";
        destDir = "/var/keys";
        permissions = "0600";
        uploadAt = "pre-activation";
      };
      "agent-token.key" = {
        keyFile = "/var/keys/clusters/${thisCluster.name}/agent-token.key";
        destDir = "/var/keys";
        permissions = "0600";
        uploadAt = "pre-activation";
      };
    };

    systemd.services.rke2-server = {
      unitConfig = {
        # The service will stay in 'inactive' state until this file exists
        AssertPathExists = if isMaster then "/var/keys/token.key" else "/var/keys/agent-token.key";
      };
    };
  };
}
