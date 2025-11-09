{ pkgs, config, lib, inputs, ... }:
{
    imports = [];

    options = {
        libraryofalexandria.manifests = {
            enable = lib.mkEnableOption "Apply manifests on this cluster";
            manifestsToApply = lib.mkOption {
                type = lib.types.listOf lib.types.attrset;
            };
        };
    };

    config = let
        package = pkgs.runCommand "render-k8s-manifest" {
            json = builtins.toJSON {
                apiVersion = "v1";
                kind = "List";
                items = config.libraryofalexandria.manifests.manifestsToApply;
            };
            passAsFile = [ "json" ]; # will be available as `$jsonPath`
        } ''
            mkdir -p $out
            cat "$jsonPath" > $out/manifest.json
        '';
    in
    lib.mkIf config.libraryofalexandria.manifests.enable {
        warnings = [''Only use this if helm charts are somehow unsuitable for the task.''];

        systemd.services.manifest-installer = {
            wantedBy = [ "${config.libraryofalexandria.cluster.k8sEngine}.service" ];
            after = [ "${config.libraryofalexandria.cluster.k8sEngine}.service" ];
            script = ''
                ${pkgs.kubectl}/bin/kubectl apply -f ${chart.config.package}/manifest.json
            '';
        };
    };
}