# Usage:
# lib2.fetchRke2Asset "rke2-images" { "linux-amd64" = "abc..."; "linux-arm64" = "def..."; }
name: sha256s:
{ pkgs, lib, ... }@args:
let
    rke2Version = pkgs.rke2.version;
    rke2VersionUrlEncoded = lib.escapeURL rke2Version;
    rke2Arch = import ./get-rke2-arch.nix { inherit pkgs; };
    fileUrl = "https://github.com/rancher/rke2/releases/download/v${rke2VersionUrlEncoded}/${name}.${rke2Arch}.tar.zst";
    sha256 = sha256s.${rke2Arch};
in
pkgs.stdenv.mkDerivation {
    pname = name;
    version = pkgs.rke2.version;

    src = pkgs.fetchurl {
        url = fileUrl;
        inherit sha256;
    };

    installPhase = ''
        echo "Downloaded file path is: $src"

        # Create the final destination directory in $out (the output path of the derivation)
        mkdir -p $out/artifacts

        # Copy the downloaded file from the store path ($src) to the final output ($out)
        cp $src $out/artifacts

        echo "File installed to $out/artifacts"
    '';
}