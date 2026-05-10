{
  pkgs,
  lib,
  config,
  lib2,
  ...
}:
{
  options = {
    users.users = lib.mkOption {
      type = lib.types.attrsOf (
        lib.types.submodule {
          options = {
            yubikeys = lib.mkOption {
              type = lib.types.listOf lib.types.str;
              default = [ ];
              description = ''
                List of YubiKey U2F authorization strings for pam_u2f.
                Generate with `pamu2fcfg -n`. 
                Do NOT include the `username:` prefix, just the base64 string.

                Does not auto enable on display managers (e.g. gdm)
              '';
            };
          };
        }
      );
    };
  };

  config =
    let
      allYubikeyUsers = lib.filterAttrs (name: user: user.yubikeys != [ ]) config.users.users;
      allYubikeys = lib.mapAttrsToList (
        name: userCfg: "${name}:${lib.concatStringsSep ":" userCfg.yubikeys}"
      ) allYubikeyUsers;
    in
    lib.mkIf (allYubikeys != [ ]) {
      environment.etc."Yubico/u2f_keys".text = lib.concatStringsSep "\n" allYubikeys;

      # Enable the U2F PAM module
      security.pam.u2f = {
        enable = true;
        settings = {
          cue = true; # Tells you to touch the key
          authfile = "/etc/Yubico/u2f_keys"; # Force it to use the declarative file
          origin = "pam://${config.libraryofalexandria.cluster.name}.loa.internal";
          appid = "pam://${config.libraryofalexandria.cluster.name}.loa.internal";
        };
      };

      # Explicitly enable U2F for your login services
      security.pam.services = {
        login.u2fAuth = true;
        sudo.u2fAuth = true;
        # gdm.u2fAuth = true; # Uncomment and change to your display manager (e.g., sddm, lightdm)
      };
    };
}
