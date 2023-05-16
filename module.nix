{ config, lib, pkgs, ... }:
let
  diskoLib = import ./lib {
    inherit lib;
    rootMountPoint = config.disko.rootMountPoint;
  };
  cfg = config.disko;
  checked = cfg.checkScripts;
in
{
  options.disko = {
    devices = lib.mkOption {
      type = diskoLib.devices;
      default = { };
      description = "The devices to set up";
    };
    rootMountPoint = lib.mkOption {
      type = lib.types.str;
      default = "/mnt";
      description = "Where the device tree should be mounted by the mountScript";
    };
    enableConfig = lib.mkOption {
      description = ''
        configure nixos with the specified devices
        should be true if the system is booted with those devices
        should be false on an installer image etc.
      '';
      type = lib.types.bool;
      default = true;
    };
    checkScripts = lib.mkOption {
      description = ''
        Whether to run shellcheck on script outputs
      '';
      type = lib.types.bool;
      default = false;
    };
  };
  config = lib.mkIf (cfg.devices.disk != { }) {
    system.build.formatScript = (diskoLib.writeCheckedBash { inherit pkgs checked; }) "disko-create" ''
      export PATH=${lib.makeBinPath (diskoLib.packages cfg.devices pkgs)}:$PATH
      ${diskoLib.create cfg.devices}
    '';

    system.build.mountScript = (diskoLib.writeCheckedBash { inherit pkgs checked; }) "disko-mount" ''
      export PATH=${lib.makeBinPath (diskoLib.packages cfg.devices pkgs)}:$PATH
      ${diskoLib.mount cfg.devices}
    '';

    system.build.disko = (diskoLib.writeCheckedBash { inherit pkgs checked; }) "disko" ''
      export PATH=${lib.makeBinPath (diskoLib.packages cfg.devices pkgs)}:$PATH
      ${diskoLib.zapCreateMount cfg.devices}
    '';

    # This is useful to skip copying executables uploading a script to an in-memory installer
    system.build.diskoNoDeps = (diskoLib.writeCheckedBash { inherit pkgs checked; noDeps = true; }) "disko" ''
      ${diskoLib.zapCreateMount cfg.devices}
    '';

    # Remember to add config keys here if they are added to types
    fileSystems = lib.mkIf cfg.enableConfig (lib.mkMerge (lib.catAttrs "fileSystems" (diskoLib.config cfg.devices)));
    boot = lib.mkIf cfg.enableConfig (lib.mkMerge (lib.catAttrs "boot" (diskoLib.config cfg.devices)));
    swapDevices = lib.mkIf cfg.enableConfig (lib.mkMerge (lib.catAttrs "swapDevices" (diskoLib.config cfg.devices)));
  };
}
