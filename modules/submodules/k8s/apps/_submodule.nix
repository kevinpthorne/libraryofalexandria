{ lib, ... }:
{
  options = {
    repo = lib.mkOption {
      type = lib.types.str;
    };
    subPath = lib.mkOption {
      type = lib.types.str;
      default = ".";
    };
    targetRevision = lib.mkOption {
      type = lib.types.str;
      default = "HEAD";
    };
    project = lib.mkOption {
      type = lib.types.str;
      default = "default";
    };
    valuesOverrides = lib.mkOption {
      type = lib.types.attrs;
      default = { };
    };
  };
}
