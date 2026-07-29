{
  lib,
  rustPlatform,
  fetchFromGitHub,
  pkg-config,
  openssl,
  libopus,
  libtiff,
  cmake,
  ...
}:

rustPlatform.buildRustPackage rec {
  pname = "sipcord-bridge";
  version = "0.1.0";

  src = fetchFromGitHub {
    owner = "coral";
    repo = "sipcord-bridge";
    rev = "1ff12ecdff103b32e01dfd80e845d2397152f466";
    hash = "sha256-QVC2cbyM1vkLA+/IKBMO2uzvK7N4JfelbP4xvn3+9Xk=";
  };

  cargoLock = {
    lockFile = ./Cargo.lock;
  };

  nativeBuildInputs = [
    pkg-config
    cmake
  ];

  buildInputs = [
    openssl
    libopus
    libtiff
  ];

  meta = with lib; {
    description = "SIP to Discord voice bridge service";
    homepage = "https://github.com/coral/sipcord-bridge";
    license = licenses.mit;
    mainProgram = "sipcord-bridge";
  };
}
