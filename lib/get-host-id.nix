lib:
cluster: node:

let
  clusterId = cluster.id;
  hostType = if node.type == "master" then 0 else 1;
  nodeId = node.id;

  combinedInt = (clusterId * 33554432) + (hostType * 16777216) + nodeId;
  
  # Convert to hex
  rawHex = lib.toHexString combinedInt;

  # Pad to 8 characters
  pad8 = s: if builtins.stringLength s < 8 then pad8 ("0" + s) else s;
in
  pad8 rawHex