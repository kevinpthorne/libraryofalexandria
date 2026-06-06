{ ... }:
{
  config.libraryofalexandria.control-plane.longhorn.values = {
    defaultSettings = {
      # Gives a node 60 minutes to return before triggering a rebuild (in seconds)
      replicaReplenishmentWaitInterval = 3600;

      # Prevents rebuild storms from saturating the Gigabit network
      concurrentReplicaRebuildPerNodeLimit = 1;

      # Ensures Longhorn only syncs the delta data if the node reconnects in time
      fastReplicaRebuildEnabled = true;
    };
  };
}
