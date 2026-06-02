{ lib, modulesPath, ... }:
{
  imports = [
    "${modulesPath}/virtualisation/azure-common.nix"
  ];

  boot.loader.grub = {
    enable = true;
    efiSupport = true;
    device = "nodev";
    efiInstallAsRemovable = true;
    font = null;
    splashImage = null;
  };
  boot.loader.efi.canTouchEfiVariables = false;

  boot.growPartition = true;

  # Keep systemd-growfs enabled on one BTRFS mount so Azure OS disk expansion
  # grows the underlying filesystem after boot.growPartition expands the GPT.
  fileSystems."/".autoResize = true;

  networking.hostName = lib.mkForce "";
  networking.enableIPv6 = false;

  services.cloud-init.settings = {
    ssh_deletekeys = false;
    ssh_genkeytypes = [ ];
  };

  programs.nix-ld.enable = true;

  systemd.tmpfiles.rules = [
    "d /opt 0755 root root -"
  ];
}
