{
  pkgs,
  config,
  ...
}:
{
  config = {
    # Ensure the directory exists
    systemd.tmpfiles.rules = [
      "d /var/lib/fake-hwclock 0755 root root -"
    ];

    # Timer to save time to disk every minute
    systemd.timers.fake-hwclock-save = {
      description = "Periodically save time to disk";
      wantedBy = [ "timers.target" ];
      timerConfig.OnCalendar = "minutely";
    };

    # Service that writes the current Epoch timestamp to disk
    systemd.services.fake-hwclock-save = {
      description = "Save system time to disk";
      script = "${pkgs.coreutils}/bin/date +%s > /var/lib/fake-hwclock/fake-hwclock.data";
      serviceConfig.Type = "oneshot";
    };

    # Service to restore time early on boot
    systemd.services.fake-hwclock-load = {
      description = "Restore system time from disk";
      wantedBy = [ "sysinit.target" ];
      after = [ "local-fs.target" ];
      before = [
        "time-sync.target"
        "sysinit.target"
        "chronyd.service"
      ];
      unitConfig.DefaultDependencies = false;

      script = ''
        if [ -f /var/lib/fake-hwclock/fake-hwclock.data ]; then
          saved_time_sec=$(cat /var/lib/fake-hwclock/fake-hwclock.data)
          current_time_sec=$(${pkgs.coreutils}/bin/date +%s)
          
          # If the system time is behind the saved time (e.g., PoE dropped and RTC reset)
          if [ "$current_time_sec" -lt "$saved_time_sec" ]; then
            ${pkgs.coreutils}/bin/date -s "@$saved_time_sec"
          fi
        fi
      '';
      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;
      };
    };
  };
}
