{ ... }@args:
let
  lib2 = import ../../lib;
in
lib2.fetchRke2Asset "rke2-images" {
  "linux-amd64" = "BADb290f0566eff6a25ae55f2ad6aab3c581cdf1361c960e9fa017e0f8defBAD";
  "linux-arm64" = "sha256-W6OWHiFQfAKqc1i45IKahM5fZw6cZuAeUplR6UHXeRY="; # 25.11
  # "linux-arm64" = "sha256-s3qCRoH5xQ/ngS2X8YwEHCXCgYnXn5YrKPfcQFeYLl0=";  # 25.05
  # "linux-arm64" = "sha256-wrKWQCC1EwK9AqFV45CK8/nvxv+QyCKXXaSHOth9XEo=";  # 24.11
} args
