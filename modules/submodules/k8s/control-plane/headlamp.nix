{ lib, lib2, config, ... }:
{
    imports = [ ../helm ];

    config = lib.mkIf config.libraryofalexandria.control-plane.headlamp.enable {
        libraryofalexandria.helmCharts.enable = true;
        libraryofalexandria.helmCharts.charts = [{
            name = "headlamp";
            chart = "headlamp/headlamp";
            version = config.libraryofalexandria.control-plane.headlamp.version;
            # https://headlamp.dev/docs/latest/installation/in-cluster/#using-helm
            values = lib2.deepMerge [{} config.libraryofalexandria.control-plane.headlamp.values];
            namespace = "kube-system";
            repo = "https://kubernetes-sigs.github.io/headlamp/";
        }];
    };
}