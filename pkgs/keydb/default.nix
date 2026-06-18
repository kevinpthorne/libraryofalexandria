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
    "BUILD_TLS=yes"
  ];

  # Configure jemalloc to support page sizes up to 64KB (2^16) for ARM64/Raspberry Pi 5 compatibility
  preBuild = ''
    patchShebangs deps/
    substituteInPlace deps/Makefile \
      --replace "--disable-cxx" "--disable-cxx --with-lg-page=16"

    # Fix linuxMadvFreeForkBugCheck assertion failure on kernels with page sizes != 4096
    # (e.g. ARM64 with 64k pages). Upstream issue: https://github.com/Snapchat/KeyDB/issues/894
    substituteInPlace src/server.cpp \
      --replace "const long map_size = 3 * 4096;" \
                "unsigned long page_size = sysconf(_SC_PAGESIZE); const long map_size = 3 * page_size;" \
      --replace "q = p + 4096;" \
                "q = p + page_size;" \
      --replace "ret = mprotect(q, 4096, PROT_READ | PROT_WRITE);" \
                "ret = mprotect(q, page_size, PROT_READ | PROT_WRITE);" \
      --replace "ret = madvise(q, 4096, MADV_FREE);" \
                "ret = madvise(q, page_size, MADV_FREE);"
  '';

  dontConfigure = true;

  meta = {
    description = "A multithreaded fork of Redis";
    homepage = "https://keydb.dev";
  };
}
