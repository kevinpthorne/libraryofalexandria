{ pkgs, ... }:
let 
  system = pkgs.stdenv.hostPlatform.system;
in
{
  aarch64-linux = "arm64";
  x86_64-linux = "amd64";
}.${system} or "unknown"