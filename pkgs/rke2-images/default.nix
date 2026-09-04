{ ... }@args:
let
  lib2 = import ../../lib;
in
lib2.fetchRke2Asset "rke2-images" {
  "linux-amd64" = "sha256-d5Rq/CoUuT2COghCL8glF46qeYIR9s2ig3yDCpqi2Fs="; # 25.11
  "linux-arm64" = "sha256-azEutD4R4DRRzBy9M2kwSDei1WrzAG608WBNnFp2blE="; # 26.06, 1.34.8+rke2r2
  # "linux-arm64" = "sha256-W6OWHiFQfAKqc1i45IKahM5fZw6cZuAeUplR6UHXeRY="; # 25.11
  # "linux-arm64" = "sha256-s3qCRoH5xQ/ngS2X8YwEHCXCgYnXn5YrKPfcQFeYLl0=";  # 25.05
  # "linux-arm64" = "sha256-wrKWQCC1EwK9AqFV45CK8/nvxv+QyCKXXaSHOth9XEo=";  # 24.11
} args
