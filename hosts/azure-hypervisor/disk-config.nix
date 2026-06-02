{ pkgs, ... }:
{
  boot.supportedFilesystems = [ "btrfs" ];

  boot.initrd.systemd.storePaths = [
    "${pkgs.btrfs-progs}/bin/btrfs"
    "${pkgs.coreutils}/bin/cut"
    "${pkgs.coreutils}/bin/mkdir"
    "${pkgs.util-linux}/bin/mount"
    "${pkgs.util-linux}/bin/umount"
  ];

  boot.initrd.systemd.services.rollback-root = {
    description = "Roll back the ephemeral BTRFS root subvolume";
    wantedBy = [ "initrd.target" ];
    requires = [ "dev-disk-by\\x2dlabel-nixos.device" ];
    after = [ "dev-disk-by\\x2dlabel-nixos.device" ];
    before = [ "sysroot.mount" ];
    unitConfig.DefaultDependencies = false;
    serviceConfig.Type = "oneshot";
    script = ''
      ${pkgs.coreutils}/bin/mkdir -p /btrfs_tmp
      ${pkgs.util-linux}/bin/mount -o subvol=/ /dev/disk/by-label/nixos /btrfs_tmp

      if [ -e /btrfs_tmp/root ]; then
        ${pkgs.btrfs-progs}/bin/btrfs subvolume list -o /btrfs_tmp/root | ${pkgs.coreutils}/bin/cut -f9- -d' ' | while read -r subvolume; do
          ${pkgs.btrfs-progs}/bin/btrfs subvolume delete "/btrfs_tmp/$subvolume"
        done
        ${pkgs.btrfs-progs}/bin/btrfs subvolume delete /btrfs_tmp/root
      fi

      ${pkgs.btrfs-progs}/bin/btrfs subvolume snapshot /btrfs_tmp/root-blank /btrfs_tmp/root
      ${pkgs.util-linux}/bin/umount /btrfs_tmp
    '';
  };

  disko.devices.disk.main = {
    device = "/dev/sda";
    type = "disk";
    content = {
      type = "gpt";
      partitions = {
        ESP = {
          type = "EF00";
          size = "512M";
          content = {
            type = "filesystem";
            format = "vfat";
            mountpoint = "/boot";
            mountOptions = [ "umask=0077" ];
          };
        };

        root = {
          size = "100%";
          content = {
            type = "btrfs";
            extraArgs = [
              "-f"
              "-L"
              "nixos"
            ];
            postCreateHook = ''
              MNTPOINT=$(mktemp -d)
              mount -t btrfs /dev/disk/by-label/nixos "$MNTPOINT"
              trap 'umount "$MNTPOINT"; rmdir "$MNTPOINT"' EXIT
              btrfs subvolume snapshot -r "$MNTPOINT/root" "$MNTPOINT/root-blank"
            '';
            subvolumes =
              let
                mountOptions = [
                  "compress=zstd:3"
                  "noatime"
                  "space_cache=v2"
                ];
              in
              {
                "/root" = {
                  mountpoint = "/";
                  inherit mountOptions;
                };

                "/nix" = {
                  mountpoint = "/nix";
                  inherit mountOptions;
                };

                "/persist" = {
                  mountpoint = "/persist";
                  inherit mountOptions;
                };

                "/log" = {
                  mountpoint = "/var/log";
                  inherit mountOptions;
                };
              };
          };
        };
      };
    };
  };

  fileSystems."/nix".neededForBoot = true;
  fileSystems."/persist".neededForBoot = true;
  fileSystems."/var/log".neededForBoot = true;
}
