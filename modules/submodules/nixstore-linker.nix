{ config, pkgs, lib, ... }:
# services.nixstore-linker = {
#   # Link 1: The original 'hello' package link
#   hello-link = {
#     targetPackage = pkgs.hello;
#     linkPath = "/etc/symlinks/hello-package";
#     ensureDirectories = [ "/etc/symlinks" ];
#   };
#   # Link 2: A link for 'git' to a specific local directory
#   git-latest = {
#     targetPackage = pkgs.git;
#     linkPath = "/opt/custom/bin/git-latest";
#     ensureDirectories = [ "/opt/custom/bin" ];
#   };
# };
let
  # Alias for configuration to keep the code clean
  cfg = config.services.nixstore-linker;
in
{
  # 1. Define the new NixOS Option structure
  options.services.nixstore-linker = lib.mkOption {
    type = lib.types.attrsOf (lib.types.submodule {
      options = {
        # The Nix package or store path to link to (e.g., pkgs.git)
        targetPackage = lib.mkOption {
          type = lib.types.unspecified; # Allows passing pkgs.somePackage directly
          description = "The Nix package or store path to be linked.";
        };
        targetPackageSubpath = lib.mkOption {
          type = lib.types.str;
          default = "";
        };
        # The absolute path where the symlink should be created (e.g., /usr/local/bin/git-latest)
        linkPath = lib.mkOption {
          type = lib.types.str;
          description = "The absolute path for the symbolic link.";
        };
        # Optional list of parent directories to ensure exist (e.g., [ "/opt/custom/bin" ])
        ensureDirectories = lib.mkOption {
          type = lib.types.listOf lib.types.str;
          default = [];
          description = "List of directories to create (mkdir -p) before making the link.";
        };
      };
    });
    default = {};
    description = "A set of persistent symlinks to Nix store paths, managed by one-shot systemd services.";
  };

  # 2. Generate a systemd service for every link defined in the new option
  config = {
    systemd.services = lib.mapAttrs'
        (name: definition:
        {
            # Service name is derived from the attribute key (e.g., "link-nix-package-hello-link")
            name = "link-nix-package-${name}";
            value = {
            description = "One-shot service to create symlink for ${name} to ${definition.linkPath}";
            serviceConfig = {
                Type = "oneshot";
                RemainAfterExit = true; # Keeps service marked as 'active' after completion
            };
            wantedBy = [ "multi-user.target" ];
            path = with pkgs; [ coreutils ]; # Ensure mkdir and ln are available

            # The command sequence executed on activation:
            script = let
                link = if definition.targetPackageSubpath == "" then definition.targetPackage else "${definition.targetPackage}/${definition.targetPackageSubpath}";
            in ''
                # 1. Ensure necessary parent directories exist
                ${lib.concatStringsSep "\n" (lib.map (dir: "${pkgs.coreutils}/bin/mkdir -p ${dir}") definition.ensureDirectories)}

                # 2. Create the symlink
                # -s: symbolic link
                # -f: force (overwrite link if it already exists)
                # ${definition.targetPackage} is interpolated as the full Nix store path
                ${pkgs.coreutils}/bin/ln -sf ${link} ${definition.linkPath}
            '';
            };
        }) cfg;
  };
}