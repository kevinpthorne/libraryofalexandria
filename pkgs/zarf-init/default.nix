 { pkgs, stdenv, ... }:
let
  # Match this strictly to the version of the `zarf` CLI package you are using!
  zarfVersion = "v${pkgs.zarf.version}"; 
  
  # Map Nix's system architecture string to Zarf's expected architecture string
  zarfArch = if stdenv.hostPlatform.system == "x86_64-linux" then "amd64"
             else if stdenv.hostPlatform.system == "aarch64-linux" then "arm64"
             else throw "Unsupported architecture for Zarf init package";

  # Purely fetch the init package tarball directly from GitHub Releases
  initTarball = pkgs.fetchurl {
    url = "https://github.com/defenseunicorns/zarf/releases/download/${zarfVersion}/zarf-init-${zarfArch}-${zarfVersion}.tar.zst";
    
    # You will need to get the real hash. You can temporarily use lib.fakeHash 
    # to force a build failure and reveal the correct hash, or run:
    # nix-prefetch-url https://github.com/.../zarf-init-...tar.zst
    sha256 = "sha256-AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA="; 
  };

in
pkgs.stdenv.mkDerivation {
  name = "zarf-init-package-${zarfVersion}";
  
  # No build inputs needed, we are just moving a file
  phases = [ "installPhase" ];
  
  installPhase = ''
    mkdir -p $out
    # We copy the fetched tarball into the output directory, maintaining 
    # the exact filename Zarf expects to see when we pass it to --package
    cp ${initTarball} $out/zarf-init-${zarfArch}-${zarfVersion}.tar.zst
  '';
}