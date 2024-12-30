{ k8s, ...} @ nodeConfig:
{ pkgs, lib, ... }:
{
    config = {
        networking.extraHosts = "${kubeMasterIP} ${kubeMasterHostname}";

        # packages for administration tasks
        environment.systemPackages = with pkgs; [
            kompose
            kubectl
            kubernetes
        ];

        services.kubernetes = let
            api = "https://${kubeMasterHostname}:${toString kubeMasterAPIServerPort}";
        in
        {
            roles = ["node"];
            masterAddress = kubeMasterHostname;
            easyCerts = true;

            # point kubelet and other services to kube-apiserver
            kubelet.kubeconfig.server = api;
            apiserverAddress = api;

            addons.dns.enable = true;
        };
    };
}