{ cluster, nodeId }:
{ lib, ... }:
{
    config = {
        libraryofalexandria.node.deployment.colmena = {
            port = 3122;
        };
    };
}