{ cluster, nodeId }:
{ ... }:
{
    config = {
        libraryofalexandria.node.deployment.colmena = {
            port = 3122;
        };
        libraryofalexandria.node.deployment.deploy-rs = {
            port = 3122;
        };
    };
}