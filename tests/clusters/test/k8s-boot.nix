{ cluster, pkgs }:
let
    concatCommands = commands: builtins.concatStringsSep "\n" commands;
    nodeList = builtins.attrNames cluster.modules;  # in nix: [ "master0" "worker0" ]
    forEachNode = func: builtins.map (nodeName: func nodeName) nodeList;
in
pkgs.nixosTest {
    name = "k8s-boot";

    nodes = cluster.modules;

    testScript = ''
        start_all()

        ${concatCommands (forEachNode (node: (
            ''
            echo "Waiting for ${node}'s kubernetes to come up"
            ${node}.wait_for_unit("kubernetes")
            ''
        )))}
    '';
}