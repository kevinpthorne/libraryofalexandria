{
  pkgs,
  ...
}:
{
  imports = [
    ../../../nixstore-linker.nix
  ];

  config = {
    services.nixstore-linker = {
      # https://docs.rke2.io/install/airgap?airgap-load-images=Manually+Deploy+Images&airgap-upgrade=Manual+Upgrade&installation-methods=Script+install#1-load-images
      rke2-images = {
        targetPackage = pkgs.rke2-images;
        targetPackageSubpath = "asset/rke2-images";
        linkPath = "/var/lib/rancher/rke2/agent/images/";
        ensureDirectories = [ "/var/lib/rancher/rke2/agent/images/" ];
      };
      rke2-images-cilium = {
        targetPackage = pkgs.rke2-images-cilium;
        targetPackageSubpath = "asset/rke2-images-cilium";
        linkPath = "/var/lib/rancher/rke2/agent/images/";
        ensureDirectories = [ "/var/lib/rancher/rke2/agent/images/" ];
      };
    };
  };
}
