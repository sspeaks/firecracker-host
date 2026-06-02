{
  config,
  lib,
  ...
}:
{
  imports = [
    ./hardware-configuration.nix
    ./microvms.nix
    ./networking.nix
    ./vm-variant.nix
  ];

  networking.hostName = "hypervisor";

  nix.settings.experimental-features = [
    "nix-command"
    "flakes"
  ];

  services.openssh = {
    enable = true;
    settings = {
      PasswordAuthentication = false;
      KbdInteractiveAuthentication = false;
      PermitRootLogin = "prohibit-password";
    };
  };

  sops = {
    defaultSopsFile = ../../secrets/host.yaml;
    validateSopsFiles = false;
    age.sshKeyPaths = [ "/etc/ssh/ssh_host_ed25519_key" ];
  };

  assertions = [
    {
      assertion = !config.sops.validateSopsFiles;
      message = "Initial scaffold disables sops file validation until real encrypted secrets are created.";
    }
  ];

  system.stateVersion = "25.05";
}
