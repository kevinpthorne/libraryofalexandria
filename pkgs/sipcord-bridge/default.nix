{
  lib,
  rustPlatform,
  fetchFromGitHub,
  pkg-config,
  openssl,
  libopus,
  libtiff,
  spandsp,
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

  RUSTC_BOOTSTRAP = 1;

  env = {
    SPANDSP_NO_VENDOR = "1";
    CFLAGS = "-I${spandsp.dev or spandsp}/include -U__STRICT_ANSI__ -D_GNU_SOURCE -D_DEFAULT_SOURCE -Wno-error -Wno-implicit-function-declaration -Wno-incompatible-pointer-types -Wno-int-conversion -Wno-implicit-int -std=gnu99";
    NIX_CFLAGS_COMPILE = "-I${spandsp.dev or spandsp}/include -U__STRICT_ANSI__ -D_GNU_SOURCE -D_DEFAULT_SOURCE -Wno-error -Wno-implicit-function-declaration -Wno-incompatible-pointer-types -Wno-int-conversion -Wno-implicit-int -std=gnu99";
  };

  postPatch = ''
    chmod -R +w . 2>/dev/null || true
    find . -name "Cargo.toml" -exec sed -i 's/rust-version = "1.9[2-9]"/rust-version = "1.91"/g' {} +
  '';

  preBuild = ''
    chmod -R +w /build 2>/dev/null || true
    find . -name "Cargo.toml" -exec sed -i 's/rust-version = "1.9[2-9]"/rust-version = "1.91"/g' {} + 2>/dev/null || true
    if [ -d "/build/cargo-vendor-dir" ]; then
      chmod -R +w /build/cargo-vendor-dir 2>/dev/null || true
      find /build/cargo-vendor-dir -name "Cargo.toml" -exec sed -i 's/rust-version = "1.9[2-9]"/rust-version = "1.91"/g' {} + 2>/dev/null || true
      find /build/cargo-vendor-dir -name "build.rs" -exec sed -i 's/"-std=c99"/"-std=gnu99"/g' {} + 2>/dev/null || true
      find /build/cargo-vendor-dir -name "build.rs" -exec sed -i 's/\.flag("-std=c99")/\.flag("-std=gnu99")/g' {} + 2>/dev/null || true
    fi
  '';

  nativeBuildInputs = [
    pkg-config
    cmake
  ];

  buildInputs = [
    openssl
    libopus
    libtiff
    spandsp
  ];

  meta = with lib; {
    description = "SIP to Discord voice bridge service";
    homepage = "https://github.com/coral/sipcord-bridge";
    license = licenses.mit;
    mainProgram = "sipcord-bridge";
  };
}
