{
  stdenv,
  fetchFromGitHub,
  pkg-config,
  gnumake,
  glib,
  zlib,
  openssl,
  pcre,
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
  ];

  buildInputs = [
    glib
    zlib
    openssl
    pcre
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
  ];

  # The rtpengine Makefile looks for bencode library, which is included in the source tree.
  buildPhase = ''
    make -C daemon
  '';

  installPhase = ''
    mkdir -p $out/bin
    cp daemon/rtpengine $out/bin/
  '';
}
