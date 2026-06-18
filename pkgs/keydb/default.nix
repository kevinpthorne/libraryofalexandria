{
  stdenv,
  fetchFromGitHub,
  pkg-config,
  openssl,
  libuuid,
  curl,
  ...
}:

stdenv.mkDerivation rec {
  pname = "keydb";
  version = "6.3.4";

  src = fetchFromGitHub {
    owner = "Snapchat";
    repo = "KeyDB";
    rev = "v${version}";
    sha256 = "118hy25l2hm03hk7fpcv88pdfvnd76jc0qsgxadzy5pplcms1alg";
  };

  nativeBuildInputs = [ pkg-config ];
  buildInputs = [
    openssl
    libuuid
    curl
  ];

  makeFlags = [
    "PREFIX=$(out)"
  ];

  # Configure jemalloc to support page sizes up to 64KB (2^16) for ARM64/Raspberry Pi 5 compatibility
  preBuild = ''
    patchShebangs deps/
    substituteInPlace deps/Makefile \
      --replace "--disable-cxx" "--disable-cxx --with-lg-page=16"
  '';

  dontConfigure = true;

  meta = {
    description = "A multithreaded fork of Redis";
    homepage = "https://keydb.dev";
  };
}
