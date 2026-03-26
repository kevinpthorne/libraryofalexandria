{ cluster, nodeId }:
{ ... }:
{
    config = {
        libraryofalexandria.node.deployment.colmena = {
            port = 3022;
        };
        libraryofalexandria.node.deployment.deploy-rs = {
            port = 3022;
        };
    };
}