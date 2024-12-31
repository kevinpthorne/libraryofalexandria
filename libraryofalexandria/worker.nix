{ k8s, ...} @ nodeConfig:
{ pkgs, lib, ... }:
with k8s; {
    config = {
        networking.extraHosts = "${masterIp} ${masterHostname}";

        # packages for administration tasks
        environment.systemPackages = with pkgs; [
            kompose
            kubectl
            kubernetes
        ];

        services.kubernetes = let
            api = "https://${masterHostname}:${toString masterPort}";
        in
        {
            roles = ["node"];
            masterAddress = masterHostname;
            easyCerts = true;

            # point kubelet and other services to kube-apiserver
            kubelet.kubeconfig.server = api;
            apiserverAddress = api;

            addons.dns.enable = true;
        };
    };
}