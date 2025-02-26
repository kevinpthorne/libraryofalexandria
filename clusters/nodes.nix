lib:
{
    count = lib.mkOption {
        type = lib.types.ints.positive;   
    };

    modules = lib.mkOption {};
}