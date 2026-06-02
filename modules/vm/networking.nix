{ inventory, vm, ... }:
{
  systemd.network.networks."10-eth" = {
    matchConfig.MACAddress = vm.mac;
    networkConfig = {
      DHCP = "ipv4";
      DNS = inventory.network.dns;
    };
  };
}
