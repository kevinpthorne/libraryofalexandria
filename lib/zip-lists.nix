lib: names: values:
builtins.listToAttrs (
  lib.zipListsWith (name: value: {
    name = name;
    value = value;
  }) names values
)
