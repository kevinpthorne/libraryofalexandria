# TODO(kevinpthorne): redo how this module works. It's messy
{ ... }:
{
    imports = [
        ./submodules/k8s/apps/control-plane
        ./submodules/k8s/apps
    ];
}