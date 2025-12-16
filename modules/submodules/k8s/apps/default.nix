{ pkgs, config, lib, lib2, inputs, ... }:
{
    imports = [  # top installs last
        ./loa-extras.nix
        ./loa-observability.nix
        ./loa-federation.nix
        ./loa-authn.nix
        ./loa-core.nix
    ];

    config = lib.mkIf (config.libraryofalexandria.apps.argocd.enable && config.libraryofalexandria.apps."${config.libraryofalexandria.cluster.name}-apps".enable) {
        libraryofalexandria.helmCharts.enable = true;
        libraryofalexandria.helmCharts.charts = lib.mkAfter [
            {
                name = "${config.libraryofalexandria.cluster.name}-apps";
                chart = "${pkgs.argocd-app-helm}";
                values = lib2.deepMerge [{
                    source = {
                        repoURL = "https://github.com/kevinpthorne/libraryofalexandria.git";
                        path = "apps/${config.libraryofalexandria.cluster.name}-apps";
                    };
                    cluster = config.libraryofalexandria.cluster;
                } config.libraryofalexandria.apps."${config.libraryofalexandria.cluster.name}-apps".values];
                namespace = "argo-cd";
            }
        ];
    };
}