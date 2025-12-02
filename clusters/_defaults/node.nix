{ cluster, nodeId }:
{ pkgs, lib, lib2, ... }:
{
    imports = [
        ../../modules/node.nix
    ];

    config = {
        libraryofalexandria = {
            cluster = lib2.getClusterConfig lib cluster;
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