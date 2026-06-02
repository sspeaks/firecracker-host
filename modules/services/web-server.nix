{ config, ... }:
{
  sops.secrets."web/message" = {
    owner = "nginx";
    group = "nginx";
    mode = "0440";
    restartUnits = [ "nginx.service" ];
  };

  services.nginx = {
    enable = true;
    recommendedGzipSettings = true;
    recommendedOptimisation = true;
    recommendedProxySettings = true;

    virtualHosts."web-01.vm.internal" = {
      default = true;
      locations."/" = {
        return = "200 'web-01 is managed by NixOS in a Firecracker microVM\\n'";
        extraConfig = "add_header Content-Type text/plain;";
      };
    };
  };

  networking.firewall.allowedTCPPorts = [ 80 ];
}
