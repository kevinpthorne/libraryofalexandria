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
    outputHashes = {
      "poise-0.6.1" = "sha256-qCTEkOWCpKgEXCt7apg+tiScE+X0Br0giTNNBxqNCs0=";
      "serenity-0.12.5" = "sha256-8I9rGKL/a8jwbLnDYV/jZEi+rDuLAn6Nk/QAJr00Kxo=";
      "serenity-voice-model-0.3.0" = "sha256-ZGwzX+saQ7RY8BtpuxzCC24vc/uQWuRWoi88ZzuJL1o=";
      "songbird-0.5.0" = "sha256-wacSNkIjA1rsENNPbo/KVDfoMXllrr+vA2pmPxsNzEs=";
    };
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
