{ cluster, nodeId }:
{ pkgs, lib, ... }:
{
    imports = [
        ../../modules/node.nix
    ];

    config = {
        libraryofalexandria = {
            inherit cluster;
            node = {
                enable = true;
                clusterName = cluster.name;
                masterIps = cluster.masters.ips;
                id = nodeId;

                deployment.colmena.enable = (cluster.deploymentMethod == "colmena");
            };
        };
    };
}