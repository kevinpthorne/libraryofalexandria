{
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
      "AzXU2kTm8cM7KyObKw62TXsombRRK7KyLGwoaVSAAq4H15xmlOXPwQ1hISJwX4VjvFRTv0O8u2kh8MQRNPWvPg==,LNZbKGbGnaG6+SYhb7S2O0A3534BG02ofzUYeFksFneHSUacarSY4Uavo3MF+6EX9HzggBkQOhP3Rt8Ib1zb8g==,es256,+presence"
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
}