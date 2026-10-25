{ pkgs, ... }:

{
  power.ups = {
    enable = true;
    mode = "standalone";
    upsmon.enable = false; # kushd handles monitoring and cluster orchestration
    upsd.listen = [
      {
        address = "127.0.0.1";
        port = 3493;
      }
      {
        address = "::1";
        port = 3493;
      }
    ];
    ups.ups = {
      driver = "usbhid-ups";
      port = "auto";
      description = "APC Back-UPS";
    };
    maxStartDelay = 30;
  };
}
