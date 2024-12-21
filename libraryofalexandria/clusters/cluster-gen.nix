clusterLabel: 
masterDefinition: 
numMasters: 
workerDefinition:
numWorkers:
let
    range = n: builtins.genList (x: x) n;
    masterIds = range numMasters;
    workerIds = range numWorkers;
    mastersList = builtins.map (n: masterDefinition clusterLabel n) masterIds;
    workersList = builtins.map (n: workerDefinition clusterLabel n) workerIds;
    mastersConfigs = builtins.foldl' (prev: master: prev // master) {} mastersList;
    workersConfigs = builtins.foldl' (prev: worker: prev // worker) {} workersList;
in
mastersConfigs // workersConfigs