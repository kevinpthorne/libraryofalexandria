{ lib, ... }:
let
  lib2 = import ../../lib;
  getHostId = lib2.getHostId lib;
  testCase = clusterId: nodeType: nodeId: getHostId {
    id = clusterId;
  } {
    type = nodeType;
    id = nodeId;
  };
in
  assert (testCase 126 "worker" 16777215) == "FDFFFFFF";
  assert (testCase 1 "master" 0) == "02000000";
  "valid"