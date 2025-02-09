inputs @ { ... }:
{
    name = "k";
    system = "aarch64-linux";

    masters = {
        count = 1;
        nixosModules = [];
    };
    workers = 4;
}