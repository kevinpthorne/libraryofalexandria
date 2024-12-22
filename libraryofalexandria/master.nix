{ k8s, ...} @ nodeConfig:
{ pkgs, lib, ... }:
with k8s; {
    config = {
        # resolve master hostname
        networking.extraHosts = "${masterIp} ${masterHostname}";

        # packages for administration tasks
        environment.systemPackages = with pkgs; [
            kompose
            kubectl
            kubernetes
        ];

        services.kubernetes = {
            roles = ["master" "node"];
            masterAddress = masterHostname;
            apiserverAddress = "https://${masterHostname}:${toString masterPort}";
            easyCerts = true;
            apiserver = {
                securePort = masterPort;
                advertiseAddress = masterIp;
            };

            # use coredns
            addons.dns.enable = true;
        };
    };
}