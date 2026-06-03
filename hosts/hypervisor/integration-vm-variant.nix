{
  inputs,
  inventory,
  lib,
  ...
}:
let
  inherit (inventory) network vms;

  vmVolume =
    name: vm:
    if vm.impermanence.enable or true then
      {
        image = "/persist/microvms/${name}/persist-integration.img";
        mountPoint = "/persist";
        size = 1024;
        fsType = "ext4";
        autoCreate = true;
      }
    else
      {
        image = "/persist/microvms/${name}/var-integration.img";
        mountPoint = "/var";
        size = 2048;
        fsType = "ext4";
        autoCreate = true;
      };

  vmMemory = name: if name == "db-01" then 1024 else 512;

  integrationConfig = name: vm: {
    imports = [
      inputs.sops-nix.nixosModules.sops
      inputs.impermanence.nixosModules.impermanence
      (../../vms + "/${name}")
    ];

    networking = {
      hostName = name;
      useNetworkd = true;
      firewall.allowedTCPPorts = [ 22 ];
    };

    microvm = {
      hypervisor = "firecracker";
      socket = "control.socket";
      vcpu = 1;
      mem = vmMemory name;
      interfaces = [
        {
          type = "tap";
          id = vm.tap;
          mac = vm.mac;
        }
      ];
      volumes = [ (vmVolume name vm) ];
      vsock.cid = vm.vsockCid;
      storeOnDisk = true;
      storeDiskType = "erofs";
    };

    services.openssh = {
      enable = true;
      settings.PermitRootLogin = "yes";
    };

    systemd.network = {
      enable = true;
      networks."10-eth" = {
        matchConfig.MACAddress = vm.mac;
        networkConfig = {
          DHCP = "ipv4";
          DNS = network.dns;
        };
      };
    };

    sops = {
      validateSopsFiles = lib.mkForce false;
      secrets = lib.mkForce { };
    };

    system.stateVersion = "25.05";
  };
in
{
  virtualisation.vmVariant =
    { pkgs, ... }:
    {
      boot.kernelParams = [ "net.ifnames=0" ];

      microvm.vms = lib.mkForce (
        lib.mapAttrs (name: vm: {
          autostart = true;
          restartIfChanged = true;
          specialArgs = {
            inherit
              inputs
              inventory
              vm
              ;
            vmName = name;
          };
          config = integrationConfig name vm;
        }) vms
      );

      networking.nat.externalInterface = lib.mkForce "eth0";

      services.getty.autologinUser = "root";
      services.openssh.settings = {
        PasswordAuthentication = lib.mkForce true;
        KbdInteractiveAuthentication = lib.mkForce true;
        PermitRootLogin = lib.mkForce "yes";
      };

      users.users.root.initialPassword = "root";

      systemd.network.networks."05-uplink" = {
        matchConfig.Name = "eth0";
        networkConfig.DHCP = "ipv4";
      };

      virtualisation = {
        cores = 4;
        diskSize = 16384;
        forwardPorts = [
          {
            from = "host";
            host.port = 2222;
            guest.port = 22;
          }
        ];
        memorySize = 6144;
        mountHostNixStore = true;
        writableStore = true;
        qemu.options = [
          "-cpu"
          "host"
        ];
      };

      environment.systemPackages = [
        inputs.microvm.packages.${pkgs.system}.microvm
        pkgs.curl
        pkgs.firecracker
        pkgs.iproute2
      ];
    };
}
