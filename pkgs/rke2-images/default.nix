{ ... }@args:
let
    lib2 = import ../../lib;
in
lib2.fetchRke2Asset "rke2-images" { 
    "linux-amd64" = "BADb290f0566eff6a25ae55f2ad6aab3c581cdf1361c960e9fa017e0f8defBAD";
    "linux-arm64" = "BADb290f0566eff6a25ae55f2ad6aab3c581cdf1361c960e9fa017e0f8defBAD";
} args