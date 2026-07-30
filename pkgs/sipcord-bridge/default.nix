{
  lib,
  stdenv,
  rustPlatform,
  fetchFromGitHub,
  pkg-config,
  openssl,
  libopus,
  libtiff,
  libjpeg,
  zlib,
  pjsip,
  cmake,
  llvmPackages,
  opencore-amr,
  alsa-lib,
  util-linux,
  ...
}:

let
  pjsipInstall = pjsip;
in
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
  doCheck = false;

  pjsipLibDir = stdenv.mkDerivation {
    name = "pjsip-normalized-libs";
    phases = [ "installPhase" ];
    installPhase = ''
      mkdir -p $out/lib $out/include

      cp -r ${pjsipInstall}/include/. $out/include/

      for lib in ${pjsipInstall}/lib/lib*.a; do
        name=$(basename "$lib")
        canonical=$(echo "$name" | sed -E 's/-(aarch64|x86_64|arm|i686)[^.]*\.a$/.a/')
        cp "$lib" "$out/lib/$canonical"
      done

      # Aliases expected by pjsua/build.rs
      [ -f "$out/lib/libpjsua.a" ] && cp "$out/lib/libpjsua.a" "$out/lib/libpjsua-lib.a"
      [ -f "$out/lib/libpj.a" ] && cp "$out/lib/libpj.a" "$out/lib/libpjlib.a"
      [ -f "$out/lib/libg7221codec.a" ] && cp "$out/lib/libg7221codec.a" "$out/lib/libg7221.a"
      [ -f "$out/lib/libgsmcodec.a" ] && cp "$out/lib/libgsmcodec.a" "$out/lib/libgsm.a"
      [ -f "$out/lib/libilbccodec.a" ] && cp "$out/lib/libilbccodec.a" "$out/lib/libilbc.a"
    '';
  };

  env = {
    PJPROJECT_DIR = pjsipLibDir;
    LIBCLANG_PATH = "${llvmPackages.libclang.lib}/lib";
    BINDGEN_EXTRA_CLANG_ARGS = "-isystem ${stdenv.cc.libc.dev}/include -isystem ${llvmPackages.libclang.lib}/lib/clang/${lib.getVersion llvmPackages.clang}/include";
    CFLAGS = "-U__STRICT_ANSI__ -D_GNU_SOURCE -D_DEFAULT_SOURCE -Wno-error -Wno-implicit-function-declaration -Wno-incompatible-pointer-types -Wno-int-conversion -Wno-implicit-int -std=gnu99";
    NIX_CFLAGS_COMPILE = "-U__STRICT_ANSI__ -D_GNU_SOURCE -D_DEFAULT_SOURCE -Wno-error -Wno-implicit-function-declaration -Wno-incompatible-pointer-types -Wno-int-conversion -Wno-implicit-int -std=gnu99";
    NIX_LDFLAGS = "-L${pjsipLibDir}/lib -lwebrtc -lyuv";
  };

  postPatch = ''
    chmod -R +w . 2>/dev/null || true
    find . -name "Cargo.toml" -exec sed -i 's/rust-version = "1.9[2-9]"/rust-version = "1.91"/g' {} +
    find . -name "*.rs" -exec sed -i 's/opt_ptr\.txt_cnt = 0;/\/\/ opt_ptr.txt_cnt = 0;/g' {} +
    find . -name "build.rs" -exec sed -i 's/"ilbc",/"ilbc", "webrtc", "yuv",/g' {} +
  '';

  preBuild = ''
    chmod -R +w /build 2>/dev/null || true
    find . -name "Cargo.toml" -exec sed -i 's/rust-version = "1.9[2-9]"/rust-version = "1.91"/g' {} + 2>/dev/null || true
    if [ -d "/build/cargo-vendor-dir" ]; then
      chmod -R +w /build/cargo-vendor-dir 2>/dev/null || true
      find /build/cargo-vendor-dir -name "Cargo.toml" -exec sed -i 's/rust-version = "1.9[2-9]"/rust-version = "1.91"/g' {} + 2>/dev/null || true
      find /build/cargo-vendor-dir -name "build.rs" -exec sed -i 's/"-std=c99"/"-std=gnu99"/g' {} + 2>/dev/null || true
      find /build/cargo-vendor-dir -name "build.rs" -exec sed -i 's/\.flag("-std=c99")/\.flag("-std=gnu99")/g' {} + 2>/dev/null || true
      find /build/cargo-vendor-dir -name "build.rs" -exec sed -i 's/"ilbc",/"ilbc", "webrtc", "yuv",/g' {} + 2>/dev/null || true
      find /build/cargo-vendor-dir -name "*.h.in" -exec sh -c 'for f; do cp -n "$f" "''${f%.in}"; done' _ {} + 2>/dev/null || true
    fi
  '';

  nativeBuildInputs = [
    pkg-config
    cmake
    llvmPackages.libclang
  ];

  buildInputs = [
    openssl
    libopus
    libtiff
    libjpeg
    zlib
    pjsip
    opencore-amr
    alsa-lib
    util-linux
  ];

  meta = with lib; {
    description = "SIP to Discord voice bridge service";
    homepage = "https://github.com/coral/sipcord-bridge";
    license = licenses.mit;
    mainProgram = "sipcord-bridge";
  };
}
