{ pkgs, config, lib, inputs, ... }:
{
    imports = [
        ./submodules/k8s/helm-charts.nix
    ];

    config = {
        libraryofalexandria.helmCharts = {
            enable = true;
            charts = [
                # {
                #     name = "main-nginx-ingress";
                #     chart = "oci://ghcr.io/nginx/charts/nginx-ingress";
                #     version = "2.0.1";
                #     # https://artifacthub.io/packages/helm/nginx-ingress-chart/nginx-ingress?modal=values
                #     values = {};
                #     namespace = "loa-infra";
                #     # TODO open nginx ports somehow
                # }
                # kubernetes-dashboard
                {
                    name = "kube-admin-ui";
                    chart = "kube-admin-ui/kubernetes-dashboard";
                    version = "7.11.1";
                    # https://artifacthub.io/packages/helm/k8s-dashboard/kubernetes-dashboard?modal=values
                    values = {
                        app = {
                            labels.loa-app = "kube-admin-ui";
                            ingress.enabled = true;
                        };
                    };
                    namespace = "kubernetes-dashboard";
                    repo = "https://kubernetes.github.io/dashboard/";
                }
                # rook-ceph https://rook.io/docs/rook/latest-release/Helm-Charts/operator-chart/
                {
                    name = "rook-ceph";
                    chart = "rook-ceph/rook-ceph";
                    version = "1.16.6";
                    values = {
                        csi = {
                            # nixos overrides
                            csiCephFSPluginVolume = [
                                {
                                    name = "lib-modules";
                                    hostPath.path = "/run/booted-system/kernel-modules/lib/modules/";
                                }
                                {
                                    name = "host-nix";
                                    hostPath.path = "/nix";
                                }
                            ];
                            csiCephFSPluginVolumeMount = [
                                {
                                    name = "host-nix";
                                    hostPath.path = "/nix";
                                }
                            ];
                            csiRBDPluginVolume = [
                                {
                                    name = "lib-modules";
                                    hostPath.path = "/run/booted-system/kernel-modules/lib/modules/";
                                }
                                {
                                    name = "host-nix";
                                    hostPath.path = "/nix";
                                }
                            ];
                            csiRBDPluginVolumeMount = [
                                {
                                    name = "host-nix";
                                    hostPath.path = "/nix";
                                }
                            ];
                        };
                        # TODO rook-ceph guide says crds.enabled = false needs to be set
                    };
                    namespace = "rook-ceph";
                    repo = "https://charts.rook.io/release";
                }
                {
                    name = "rook-ceph-cluster";
                    chart = "rook-ceph/rook-ceph-cluster"; # reuses repo from above
                    version = "1.16.6";
                    values = {
                        operatorNamespace = "rook-ceph";
                        # TODO allow overrides - idk how disks are being decided currently and rpis shouldnt use sd cards
                    };
                    namespace = "rook-ceph";
                }
                # cilium https://docs.cilium.io/en/stable/installation/k8s-install-helm/
                {
                    name = "cilium";
                    chart = "cilium/cilium";
                    version = "1.17.2";
                    values = {};
                    namespace = "kube-system";
                    repo = "https://helm.cilium.io/";
                }
                # cert-manager
                {
                    name = "cert-manager";
                    chart = "cert-manager/cert-manager";
                    version = "v1.17.0";
                    values = {
                        crds.enabled = true;
                    };
                    namespace = "cert-manager";
                    repo = "https://charts.jetstack.io";
                }
                # vault https://developer.hashicorp.com/vault/docs/platform/k8s/helm
                {
                    name = "vault";
                    chart = "vault/vault";
                    version = "1.19.0";
                    values = {
                        server = {
                            ha = {
                                enabled = true;
                                replicas = 3;
                            };
                        };
                    };
                    namespace = "vault";
                    repo = "https://helm.releases.hashicorp.com";
                }
                # istio https://istio.io/latest/docs/setup/install/helm/
                {
                    name = "istio-base";
                    chart = "istio-base/base";
                    version = "1.25.1";
                    values = {
                        defaultRevision = "default";
                    };
                    namespace = "istio-system";
                    repo = "https://istio-release.storage.googleapis.com/charts";
                }
                {
                    name = "istio-cni";
                    chart = "istio-base/cni";  # reuses repo from above
                    version = "1.25.1";
                    values = {};
                    namespace = "istio-system";
                }
                {
                    name = "istiod";
                    chart = "istio-base/istiod";  # reuses repo from above
                    version = "1.25.1";
                    values = {};
                    namespace = "istio-system";
                }
                {
                    name = "istio-ingressgateway";
                    chart = "istio-base/gateway";  # reuses repo from above
                    version = "1.25.1";
                    values = {};
                    namespace = "istio-ingress";
                }
                # argocd
                {
                    name = "argo";
                    chart = "argo/argo-cd";
                    version = "7.8.23";
                    values = {};
                    namespace = "argo-cd";
                    repo = "https://argoproj.github.io/argo-helm";
                }
            ];
        };
    };
}