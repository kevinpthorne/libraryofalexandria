isEntering:
if isEntering then
    nodeConfig:
    {
        k8s = {
            masterIp = "10.69.69.100";
            masterHostname = nodeConfig.hostname;
            masterPort = 6443;
        };
    }
else
    nodeConfig:
    {}