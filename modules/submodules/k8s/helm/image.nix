{ pkgs, lib, config, lib2, ... }:
{
  options = {
    imageName = lib.mkOption {
      type = lib.types.str;
    };

    imageDigest = lib.mkOption {
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
      imageName = config.imageName;
      imageDigest = config.imageDigest;
      finalImageTag = config.finalImageTag;
      sha256 = config.hash;
      arch = lib2.getGoArch { inherit pkgs; };
      os = "linux";
    };
  };
}