{ ... }:
{
  config = {
    users.users.kevint = {
      isNormalUser = true;
      openssh.authorizedKeys.keys = [
        "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIFz9z1zkXXO45SjKKbryrXZip/HEvZSAV2D/WpygFSFK kevint@Laptop4.local"
      ];
      extraGroups = [
        "wheel"
        "networkmanager"
      ];
      yubikeys = [
        "Waj207HIhJmoTQY7aqF/TnxFovRp8cAgheRz1etZ3XTPtQ2IYafYnFZvZE3nVT+1c3qT/VifdI/oUadFc24ZNQ==,uDPHANGUrkiov04JAil2OxmC8a8a4rv9VSsdqGLLhcQyTstGq/fAUkr92FVntZq6mfskRtnNeTJZHbFqIDNaZA==,es256,+presence" # pam://k.loa.internal
      ];
    };

    security.sudo.extraRules = [
      # colmena currently requires non-interactive auth
      {
        users = [ "kevint" ];
        commands = [
          {
            command = "ALL";
            options = [ "NOPASSWD" ]; # "SETENV" # Adding the following could be a good idea
          }
        ];
      }
    ];
    nix.settings = {
      trusted-users = [ "kevint" ];
    };
  };
}
