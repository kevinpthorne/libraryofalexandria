{ cluster, nodeId }:
{ ... }:
{
  config = {
    libraryofalexandria.node.deployment.colmena = {
      port = 3222;
    };
    libraryofalexandria.node.deployment.deploy-rs = {
      port = 3222;
    };
  };
}
