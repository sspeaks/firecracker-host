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
        image = "/persist/microvms/${name}/persist-smoke.img";
        mountPoint = "/persist";
        size = 512;
        fsType = "ext4";
        autoCreate = true;
      }
    else
      {
        image = "/persist/microvms/${name}/var-smoke.img";
        mountPoint = "/var";
        size = 512;
        fsType = "ext4";
        autoCreate = true;
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
          config = {
            networking = {
              hostName = name;
              useNetworkd = true;
              firewall.allowedTCPPorts = [ 22 ];
            };

            microvm = {
              hypervisor = "firecracker";
              socket = "control.socket";
              vcpu = 1;
              mem = 384;
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

            system.stateVersion = "25.05";
          };
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
