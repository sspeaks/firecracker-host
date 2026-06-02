{ inventory, lib, ... }:
let
  inherit (inventory) network vms;
  bridgeCidr = "${network.bridgeAddress}/${toString network.bridgePrefix}";
in
{
  networking.useNetworkd = true;
  systemd.network.enable = true;

  systemd.network.netdevs."10-${network.bridgeName}".netdevConfig = {
    Kind = "bridge";
    Name = network.bridgeName;
  };

  systemd.network.networks."10-${network.bridgeName}" = {
    matchConfig.Name = network.bridgeName;
    networkConfig = {
      Address = bridgeCidr;
      DHCPServer = true;
      IPv6SendRA = false;
    };
    dhcpServerStaticLeases = lib.mapAttrsToList (_name: vm: {
      MACAddress = vm.mac;
      Address = vm.ipv4;
    }) vms;
  };

  systemd.network.networks."20-vm-taps" = {
    matchConfig.Name = "vm-*";
    networkConfig.Bridge = network.bridgeName;
  };

  networking.nat = {
    enable = true;
    externalInterface = network.externalInterface;
    internalInterfaces = [ network.bridgeName ];
  };

  networking.firewall.allowedUDPPorts = [ 67 ];
}
