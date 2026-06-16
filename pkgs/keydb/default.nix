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
    "MALLOC=libc"
    "PREFIX=$(out)"
  ];

  preBuild = ''
    patchShebangs deps/
  '';

  dontConfigure = true;

  meta = {
    description = "A multithreaded fork of Redis";
    homepage = "https://keydb.dev";
  };
}
