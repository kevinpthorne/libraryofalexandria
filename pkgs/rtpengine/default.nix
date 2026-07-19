{
  stdenv,
  fetchFromGitHub,
  pkg-config,
  gnumake,
  glib,
  zlib,
  openssl,
  pcre2,
  curl,
  xmlrpc_c,
  hiredis,
  iptables,
  libevent,
  libpcap,
  json-glib,
  ffmpeg,
  spandsp,
  libwebsockets,
  mariadb-connector-c,
  libcap,
  libnftnl,
  libmnl,
  libopus,
  libxml2,
  perl,
  gperf,
  ...
}:

stdenv.mkDerivation rec {
  pname = "rtpengine";
  version = "12.5.1.4";

  src = fetchFromGitHub {
    owner = "sipwise";
    repo = "rtpengine";
    rev = "mr${version}";
    sha256 = "00yjyacbdss6p817hjlbgqdzzlfp3zd84licg27zziihspziak7z";
  };

  nativeBuildInputs = [
    pkg-config
    gnumake
    perl
    gperf
  ];

  NIX_CFLAGS_COMPILE = "-Wno-error=incompatible-pointer-types";

  buildInputs = [
    glib
    zlib
    openssl
    pcre2
    curl
    xmlrpc_c
    hiredis
    iptables
    libevent
    libpcap
    json-glib
    ffmpeg
    spandsp
    libwebsockets
    mariadb-connector-c
    libcap
    libnftnl
    libmnl
    libopus
    libxml2
  ];

  postPatch = ''
    substituteInPlace utils/const_str_hash \
      --replace-warn "#!/usr/bin/perl" "#!${perl}/bin/perl" \
      --replace-warn "#! /usr/bin/perl" "#!${perl}/bin/perl"
    chmod +x utils/const_str_hash
  '';

  # The rtpengine Makefile looks for bencode library, which is included in the source tree.
  buildPhase = ''
    make -C daemon
  '';

  installPhase = ''
    mkdir -p $out/bin
    cp daemon/rtpengine $out/bin/
  '';
}
