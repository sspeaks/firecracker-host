{ lib, ... }:
{
  # flake.nix sets the effective host platform per architecture with mkForce.
  # Replace this default with generated hardware config before real deployment.
  nixpkgs.hostPlatform = lib.mkDefault "x86_64-linux";

  # Replace these placeholders with the generated hardware-configuration.nix for
  # the physical hypervisor before deploying to real hardware.
  fileSystems."/" = {
    device = "/dev/disk/by-label/nixos";
    fsType = "ext4";
  };

  boot.loader.systemd-boot.enable = lib.mkDefault true;
  boot.loader.efi.canTouchEfiVariables = lib.mkDefault true;
}
