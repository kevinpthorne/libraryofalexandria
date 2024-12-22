isEntering:
if isEntering then
    nodeConfig:
    {
        k8s = {
            masterIp = "172.24.1.178";
            masterHostname = nodeConfig.hostname;
            masterPort = 6443;
        };
    }
else
    nodeConfig:
    {}