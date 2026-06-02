{
  config,
  lib,
  vm,
  vmName,
  ...
}:
let
  cfg = config.firecracker.impermanence;
  vmStateDir = "/persist/microvms/${vmName}";
in
{
  options.firecracker.impermanence = {
    enable = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = ''
        Whether this VM uses curated impermanence. When disabled, the VM
        preserves the current full /var persistence behavior.
      '';
    };

    persistRoot = lib.mkOption {
      type = lib.types.str;
      default = "/persist";
      description = "Guest mount point used as the persistent storage root.";
    };

    extraDirectories = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ ];
      description = "Additional guest directories to persist when impermanence is enabled.";
    };

    extraFiles = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ ];
      description = "Additional guest files to persist when impermanence is enabled.";
    };
  };

  config = lib.mkMerge [
    (lib.mkIf cfg.enable {
      microvm.volumes = [
        {
          image = "${vmStateDir}/persist.img";
          mountPoint = cfg.persistRoot;
          size = vm.dataDiskMiB;
          fsType = "ext4";
          autoCreate = true;
        }
      ];

      fileSystems.${cfg.persistRoot}.neededForBoot = lib.mkDefault true;

      environment.persistence.${cfg.persistRoot} = {
        hideMounts = true;
        directories = [
          "/etc/ssh"
          "/var/lib/nixos"
          "/var/lib/sops-nix"
        ]
        ++ cfg.extraDirectories;
        files = [
          "/etc/machine-id"
        ]
        ++ cfg.extraFiles;
      };
    })

    (lib.mkIf (!cfg.enable) {
      microvm.volumes = [
        {
          image = "${vmStateDir}/var.img";
          mountPoint = "/var";
          size = vm.dataDiskMiB;
          fsType = "ext4";
          autoCreate = true;
        }
      ];

      fileSystems."/var".neededForBoot = lib.mkDefault true;

      environment.persistence."/var/persist" = {
        hideMounts = true;
        directories = [
          "/etc/ssh"
        ];
        files = [
          "/etc/machine-id"
        ];
      };
    })
  ];
}
