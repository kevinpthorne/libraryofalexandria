args:
let
  lib2 = import ../../lib;
in
lib2.buildHelmChart ./. args
