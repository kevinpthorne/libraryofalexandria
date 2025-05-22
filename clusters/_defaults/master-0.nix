{ lib, cluster, ... }: 
{
    imports = [
       ../../modules/control-plane.nix 
    ];

    config = {
        libraryofalexandria.apps = cluster.apps;
    };
}