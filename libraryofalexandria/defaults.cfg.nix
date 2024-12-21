nodeConfig:
with nodeConfig; {
    hostname = nodeType + toString nodeNumber + "-" + clusterLabel;
}