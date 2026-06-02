{
  lib,
  vm,
  vmName,
  ...
}:
{
  networking.hostName = lib.mkDefault vmName;
  networking.useNetworkd = true;

  microvm = {
    hypervisor = "firecracker";
    socket = "control.socket";

    vcpu = lib.mkDefault vm.vcpu;
    mem = lib.mkDefault vm.mem;

    interfaces = [
      {
        type = "tap";
        id = vm.tap;
        mac = vm.mac;
      }
    ];

    vsock.cid = vm.vsockCid;

    storeOnDisk = true;
    storeDiskType = "erofs";
  };

  services.openssh = {
    enable = true;
    settings = {
      PasswordAuthentication = false;
      KbdInteractiveAuthentication = false;
      PermitRootLogin = "prohibit-password";
    };
  };

  systemd.network.enable = true;

  system.stateVersion = "25.05";
}
