{
  config,
  inventory,
  lib,
  ...
}:
let
  cfg = config.firecracker.hostImpermanence;
  vmNames = builtins.attrNames inventory.vms;
in
{
  options.firecracker.hostImpermanence = {
    enable = lib.mkEnableOption "impermanence for the hypervisor host";

    persistPath = lib.mkOption {
      type = lib.types.str;
      default = "/persist";
      description = "Persistent storage root used by the hypervisor host.";
    };

    persistCloudState = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Whether to persist cloud-init state for cloud hypervisor profiles.";
    };
  };

  config = lib.mkMerge [
    {
      systemd.tmpfiles.rules = map (
        name: "d ${cfg.persistPath}/microvms/${name} 0775 microvm kvm -"
      ) vmNames;

      systemd.services."microvm@".unitConfig.RequiresMountsFor = [ cfg.persistPath ];
    }

    (lib.mkIf cfg.enable {
      sops.useSystemdActivation = lib.mkDefault true;

      environment.persistence.${cfg.persistPath} = {
        hideMounts = true;
        directories = [
          "/etc/ssh"
          "/var/lib/nixos"
          "/var/lib/sops-nix"
          "/var/lib/systemd"
        ]
        ++ lib.optionals cfg.persistCloudState [
          "/var/lib/cloud"
        ];
        files = [
          "/etc/adjtime"
          "/etc/machine-id"
        ];
      };
    })
  ];
}
