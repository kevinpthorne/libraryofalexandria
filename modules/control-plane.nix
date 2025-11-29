{ ... }:
{
    imports = [
        ./submodules/k8s/apps/control-plane
        ./submodules/k8s/apps/shared-apps.nix
    ];

    config = {
        libraryofalexandria.apps.shared-apps.enable = true;
    };
}