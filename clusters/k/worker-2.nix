{ ... }:

{
  # Override the primary network interface for this specific node (MSI GP73 laptop)
  # Update "eno1" to match whatever your actual interface name is (e.g. eno1, enp3s0)
  libraryofalexandria.node.interfaces = [ "enp5s0" ];
}
