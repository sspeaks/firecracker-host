{ vm, ... }:
{
  services.redis.servers."" = {
    enable = true;
    bind = vm.ipv4;
    port = 6379;
    openFirewall = true;
    save = [ ];
    settings.protected-mode = false;
  };
}
