thisCluster: federateTo:
let
  append = val: list: list ++ [ val ];
  alphaSort = list: builtins.sort builtins.lessThan list;
  # ...
  clusters = append thisCluster federateTo;
  sortedClusters = alphaSort clusters;
  federationName = builtins.concatStringsSep "-" sortedClusters;
in
federationName
