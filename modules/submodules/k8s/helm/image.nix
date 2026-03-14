{ pkgs, lib, config, lib2, ... }:
{
  options = {
    name = lib.mkOption {
      type = lib.types.str;
    };

    digest = lib.mkOption {
      type = lib.types.str;
    };

    hash = lib.mkOption {
      type = lib.types.str;
    };

    finalImageTag = lib.mkOption {
      type = lib.types.str;
    };

    # generated
    package = lib.mkOption {
        type = lib.types.package;
        readOnly = true;
    };
  };

  config = {
    package = pkgs.dockerTools.pullImage {
      imageName = config.name;
      imageDigest = config.digest;
      finalImageTag = config.finalImageTag;
      sha256 = config.hash;
      arch = lib2.getGoArch { inherit pkgs; };
      os = "linux";
    };
  };
}