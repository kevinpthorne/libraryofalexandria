{ pkgs, config, lib, inputs, ... }:
{
    imports = [
      ./helm
    ];

    options = {
        libraryofalexandria.zarf = {
            enable = lib.mkEnableOption "Enable zarf deployment";
        };
    };

    config = let
      zarfBundlePackage = pkgs.zarf;
      isMaster = config.libraryofalexandria.node.type == "master";
      isMaster0 = isMaster && config.libraryofalexandria.node.id == 0;
      k8sSystemdService = if config.libraryofalexandria.cluster.k8sEngine == "rke2" then "rke2-server" else "kubernetes";
    in lib.mkIf (config.libraryofalexandria.zarf.enable && isMaster0) {
      environment.systemPackages = [
          zarfBundlePackage
        ] ++ (with pkgs; [
          runonce
          zarf
          skopeo
      ]);

      systemd.services.zarf-init = {
        requires = [ "${k8sSystemdService}.service" ];
        after = [ "${k8sSystemdService}.service" ];
        script = ''
            ${pkgs.runonce} ${pkgs.zarf}/bin/zarf init
        '';
      };

      systemd.services.zarf-deploy = {
        requires = [ "zarf-init.service" ];
        after = [ "zarf-init.service" ];
        script = ''
            ${pkgs.runonce} ${pkgs.zarf}/bin/zarf package deploy ${zarfBundlePackage}
        '';
      };

    };
}