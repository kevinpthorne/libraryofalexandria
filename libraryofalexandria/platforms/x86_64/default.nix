nodeConfig:
{ pkgs, lib, ... }:
{
  config = {
    users.users.root.initialPassword = "root";
  };
}