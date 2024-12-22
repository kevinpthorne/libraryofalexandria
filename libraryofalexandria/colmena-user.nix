colmenaUsername:
{
    "${colmenaUsername}" = {
        isNormalUser = true;
        home = "/home/${colmenaUsername}";
        extraGroups = [ "wheel" "networkmanager" ];
        openssh.authorizedKeys.keys = [
            "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAICAa6gt+RvDM5hDn+GBmWnCaPo3KB6RNdG3so0q3Z8kw kevint@Laptop4.local deployment"
        ];
    };
}