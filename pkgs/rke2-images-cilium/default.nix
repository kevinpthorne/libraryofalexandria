{ ... }@args:
let
  lib2 = import ../../lib;
in
lib2.fetchRke2Asset "rke2-images-cilium" {
  "linux-amd64" = "BADb290f0566eff6a25ae55f2ad6aab3c581cdf1361c960e9fa017e0f8defBAD";
  "linux-arm64" = "sha256-jQLU73RgkpuNzI9r6DjogiRDvuVG4B8IUrFY+o6h0Y4="; # 25.11, 1.33.9+rke2r1
  # "linux-arm64" = "sha256-rrplA5hRp0VGcNZkUCf81RH2MwLaZ6B87BBnrH7J8HA="; # 25.05
  # "linux-arm64" = "sha256-9kX1ND1w/bZQp0xlyWYo1lyvdl8fPhP694Y+6yjREtw=";  # 24.11
} args
