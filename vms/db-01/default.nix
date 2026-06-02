{
  lib,
  pkgs,
  vm,
  ...
}:
{
  services.postgresql = {
    enable = true;
    package = pkgs.postgresql_16;
    dataDir = "/var/lib/postgresql/16";
    settings.listen_addresses = lib.mkForce "localhost,${vm.ipv4}";
  };

  networking.firewall.allowedTCPPorts = [ 5432 ];
}
