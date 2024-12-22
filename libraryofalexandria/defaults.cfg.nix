isEntering:
if isEntering then
    nodeConfig:
    with nodeConfig; {
        isMaster = if nodeType == "master" then true else false;
        hostname = nodeType + toString nodeNumber + "-" + clusterLabel;
    } 
else 
    nodeConfig:
    {}