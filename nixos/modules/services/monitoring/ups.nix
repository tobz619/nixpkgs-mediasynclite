{ config, lib, pkgs, ... }:

# TODO: This is not secure, have a look at the file docs/security.txt inside
# the project sources.
with lib;

let
  cfg = config.power.ups;
in

let
  upsOptions = {name, config, ...}:
  {
    options = {
      # This can be inferred from the UPS model by looking at
      # /nix/store/nut/share/driver.list
      driver = mkOption {
        type = types.str;
        description = lib.mdDoc ''
          Specify the program to run to talk to this UPS.  apcsmart,
          bestups, and sec are some examples.
        '';
      };

      port = mkOption {
        type = types.str;
        description = lib.mdDoc ''
          The serial port to which your UPS is connected.  /dev/ttyS0 is
          usually the first port on Linux boxes, for example.
        '';
      };

      shutdownOrder = mkOption {
        default = 0;
        type = types.int;
        description = lib.mdDoc ''
          When you have multiple UPSes on your system, you usually need to
          turn them off in a certain order.  upsdrvctl shuts down all the
          0s, then the 1s, 2s, and so on.  To exclude a UPS from the
          shutdown sequence, set this to -1.
        '';
      };

      maxStartDelay = mkOption {
        default = null;
        type = types.uniq (types.nullOr types.int);
        description = lib.mdDoc ''
          This can be set as a global variable above your first UPS
          definition and it can also be set in a UPS section.  This value
          controls how long upsdrvctl will wait for the driver to finish
          starting.  This keeps your system from getting stuck due to a
          broken driver or UPS.
        '';
      };

      description = mkOption {
        default = "";
        type = types.str;
        description = lib.mdDoc ''
          Description of the UPS.
        '';
      };

      directives = mkOption {
        default = [];
        type = types.listOf types.str;
        description = lib.mdDoc ''
          List of configuration directives for this UPS.
        '';
      };

      summary = mkOption {
        default = "";
        type = types.lines;
        description = lib.mdDoc ''
          Lines which would be added inside ups.conf for handling this UPS.
        '';
      };

    };

    config = {
      directives = mkOrder 10 ([
        "driver = ${config.driver}"
        "port = ${config.port}"
        ''desc = "${config.description}"''
        "sdorder = ${toString config.shutdownOrder}"
      ] ++ (optional (config.maxStartDelay != null)
            "maxstartdelay = ${toString config.maxStartDelay}")
      );

      summary =
        concatStringsSep "\n      "
          (["[${name}]"] ++ config.directives);
    };
  };

in


{
  options = {
    # powerManagement.powerDownCommands

    power.ups = {
      enable = mkOption {
        default = false;
        type = with types; bool;
        description = lib.mdDoc ''
          Enables support for Power Devices, such as Uninterruptible Power
          Supplies, Power Distribution Units and Solar Controllers.
        '';
      };

      # This option is not used yet.
      mode = mkOption {
        default = "standalone";
        type = types.str;
        description = lib.mdDoc ''
          The MODE determines which part of the NUT is to be started, and
          which configuration files must be modified.

          The values of MODE can be:

          - none: NUT is not configured, or use the Integrated Power
            Management, or use some external system to startup NUT
            components. So nothing is to be started.

          - standalone: This mode address a local only configuration, with 1
            UPS protecting the local system. This implies to start the 3 NUT
            layers (driver, upsd and upsmon) and the matching configuration
            files. This mode can also address UPS redundancy.

          - netserver: same as for the standalone configuration, but also
            need some more ACLs and possibly a specific LISTEN directive in
            upsd.conf.  Since this MODE is opened to the network, a special
            care should be applied to security concerns.

          - netclient: this mode only requires upsmon.
        '';
      };

      schedulerRules = mkOption {
        example = "/etc/nixos/upssched.conf";
        type = types.str;
        description = lib.mdDoc ''
          File which contains the rules to handle UPS events.
        '';
      };


      maxStartDelay = mkOption {
        default = 45;
        type = types.int;
        description = lib.mdDoc ''
          This can be set as a global variable above your first UPS
          definition and it can also be set in a UPS section.  This value
          controls how long upsdrvctl will wait for the driver to finish
          starting.  This keeps your system from getting stuck due to a
          broken driver or UPS.
        '';
      };

      ups = mkOption {
        default = {};
        # see nut/etc/ups.conf.sample
        description = lib.mdDoc ''
          This is where you configure all the UPSes that this system will be
          monitoring directly.  These are usually attached to serial ports,
          but USB devices are also supported.
        '';
        type = with types; attrsOf (submodule upsOptions);
      };

    };
  };

  config = mkIf cfg.enable {

    environment.systemPackages = [ pkgs.nut ];

    systemd.services.upsmon = {
      description = "Uninterruptible Power Supplies (Monitor)";
      after = [ "network.target" ];
      wantedBy = [ "multi-user.target" ];
      serviceConfig.Type = "forking";
      script = "${pkgs.nut}/sbin/upsmon";
      environment.NUT_CONFPATH = "/etc/nut/";
      environment.NUT_STATEPATH = "/var/lib/nut/";
    };

    systemd.services.upsd = {
      description = "Uninterruptible Power Supplies (Daemon)";
      after = [ "network.target" "upsmon.service" ];
      wantedBy = [ "multi-user.target" ];
      serviceConfig.Type = "forking";
      # TODO: replace 'root' by another username.
      script = "${pkgs.nut}/sbin/upsd -u root";
      environment.NUT_CONFPATH = "/etc/nut/";
      environment.NUT_STATEPATH = "/var/lib/nut/";
    };

    systemd.services.upsdrv = {
      description = "Uninterruptible Power Supplies (Register all UPS)";
      after = [ "upsd.service" ];
      wantedBy = [ "multi-user.target" ];
      # TODO: replace 'root' by another username.
      script = "${pkgs.nut}/bin/upsdrvctl -u root start";
      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;
      };
      environment.NUT_CONFPATH = "/etc/nut/";
      environment.NUT_STATEPATH = "/var/lib/nut/";
    };

    environment.etc = {
      "nut/nut.conf".source = pkgs.writeText "nut.conf"
        ''
          MODE = ${cfg.mode}
        '';
      "nut/ups.conf".source = pkgs.writeText "ups.conf"
        ''
          maxstartdelay = ${toString cfg.maxStartDelay}

          ${flip concatStringsSep (forEach (attrValues cfg.ups) (ups: ups.summary)) "

          "}
        '';
      "nut/upssched.conf".source = cfg.schedulerRules;
      # These file are containing private information and thus should not
      # be stored inside the Nix store.
      /*
      "nut/upsd.conf".source = "";
      "nut/upsd.users".source = "";
      "nut/upsmon.conf".source = "";
      */
    };

    power.ups.schedulerRules = mkDefault "${pkgs.nut}/etc/upssched.conf.sample";

    systemd.tmpfiles.rules = [
      "d /var/state/ups -"
    ];


/*
    users.users.nut =
      { uid = 84;
        home = "/var/lib/nut";
        createHome = true;
        group = "nut";
        description = "UPnP A/V Media Server user";
      };

    users.groups."nut" =
      { gid = 84; };
*/

  };
}
