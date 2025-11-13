{ pkgs, ... }:
if pkgs.system == "aarch64-linux" then "linux-arm64" else "linux-amd64"