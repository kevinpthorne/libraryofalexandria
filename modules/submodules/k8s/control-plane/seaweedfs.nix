{
  lib,
  lib2,
  config,
  pkgs,
  ...
}:
let
  isMaster = config.libraryofalexandria.node.type == "master";
  isMaster0 = isMaster && config.libraryofalexandria.node.id == 0;

  totalMasters = config.libraryofalexandria.cluster.masters.count;
  totalWorkers = config.libraryofalexandria.cluster.workers.count;
  totalNodes = totalMasters + totalWorkers;

  # Auto topology:
  # - Single node (e.g. g, test): 1 master, 1 filer, 1 volume, replication "000"
  # - Multi node (e.g. k): 3 masters (Raft quorum), 2 filers (HA), 5 volumes (1 per node), replication "001"
  autoReplication = if totalNodes <= 1 then "000" else "001";
  autoMasterReplicas = if totalMasters <= 1 then 1 else (if totalMasters >= 3 then 3 else 1);
  autoFilerReplicas = if totalNodes <= 1 then 1 else 2;
  autoVolumeReplicas = if totalNodes <= 1 then 1 else totalNodes;

  cfg = config.libraryofalexandria.control-plane.seaweedfs;

  effectiveReplication = cfg.extraOptions.replication or autoReplication;
  effectiveMasterReplicas = cfg.extraOptions.masterReplicas or autoMasterReplicas;
  effectiveFilerReplicas = cfg.extraOptions.filerReplicas or autoFilerReplicas;
  effectiveVolumeReplicas = cfg.extraOptions.volumeReplicas or autoVolumeReplicas;
  effectiveSize = cfg.extraOptions.size or "600G";
  storagePath = cfg.extraOptions.storagePath or "/var/lib/local-path-provisioner";

  migrateSeaweedfsToLocalpath = pkgs.writeShellScriptBin "migrate-seaweedfs-to-localpath" (
    builtins.readFile ../../../../scripts/migrate-seaweedfs-to-localpath.sh
  );
in
{
  imports = [ ../helm ];

  config = lib.mkIf cfg.enable {
    libraryofalexandria.helmCharts.enable = true;
    libraryofalexandria.helmCharts.charts = [
      {
        name = "local-path-provisioner";
        chart = "${pkgs.local-path-provisioner-helm}/local-path-provisioner-helm-0.1.0.tgz";
        namespace = "kube-system";
        values = {
          nodePathMap = [
            {
              node = "DEFAULT_PATH_FOR_NON_LISTED_NODES";
              paths = [ storagePath ];
            }
          ];
        };
      }
      {
        name = "seaweedfs-system-namespace";
        chart = "${pkgs.namespace-helm}/namespace-helm-0.1.0.tgz";
        values = {
          name = "seaweedfs-system";
          podSecurityLevel = {
            enforce = "privileged";
            audit = "privileged";
            warn = "privileged";
          };
        };
      }
      {
        name = "seaweedfs-operator";
        chart = "seaweedfs-operator/seaweedfs-operator";
        version = cfg.version;
        values = lib2.deepMerge [
          {
            podSecurityContext = {
              runAsNonRoot = true;
              runAsUser = 65532;
              fsGroup = 65532;
              seccompProfile.type = "RuntimeDefault";
            };
            securityContext = {
              allowPrivilegeEscalation = false;
              capabilities.drop = [ "ALL" ];
              readOnlyRootFilesystem = true;
              runAsNonRoot = true;
            };
          }
          cfg.values
        ];
        namespace = "seaweedfs-system";
        repo = "https://seaweedfs.github.io/seaweedfs-operator/";
      }
      {
        name = "seaweedfs-cluster";
        chart = "${pkgs.seaweedfs-cluster-helm}/seaweedfs-cluster-helm-0.1.0.tgz";
        namespace = "seaweedfs-system";
        values = lib2.deepMerge [
          {
            storageClass = "local-path";
            size = effectiveSize;
            replication = effectiveReplication;
            volumeReplicas = effectiveVolumeReplicas;
            masterReplicas = effectiveMasterReplicas;
            filerReplicas = effectiveFilerReplicas;
            s3Replicas = effectiveFilerReplicas;
          }
          (cfg.extraOptions.clusterValues or { })
        ];
      }
    ];

    # Install migration tool CLI on master0
    environment.systemPackages = lib.mkIf isMaster0 [
      migrateSeaweedfsToLocalpath
    ];

    systemd.tmpfiles.rules = [
      "d ${storagePath} 0750 root root -"
    ];
  };
}
