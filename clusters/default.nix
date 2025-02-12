let
    clusters = [
        "k"
    ];
    ## TODO master, worker nixosSystem definitions
    range = n: builtins.genList (x: x) n;
    masterIds = range config.masters.count;
    workerIds = range config.workers.count;
    mastersList = builtins.map (n: masterDefinition n) masterIds;
    workersList = builtins.map (n: workerDefinition n) workerIds;
    mastersConfigs = builtins.foldl' (prev: master: prev // master) {} mastersList;
    workersConfigs = builtins.foldl' (prev: worker: prev // worker) {} workersList;
in
mastersConfigs // workersConfigs