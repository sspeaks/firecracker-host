{
  config,
  lib,
  ...
}:
{
  firecracker.hostImpermanence = {
    enable = true;
    persistCloudState = true;
  };

  imports = [
    ./azure.nix
    ./disk-config.nix
    ./microvms.nix
    ./networking.nix
  ];

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
      ClientAliveInterval = 180;
    };
  };

  security.sudo.wheelNeedsPassword = false;

  users.users = {
    root = {
      hashedPassword = "!";
      openssh.authorizedKeys.keys = [
        "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABgQC0XL/A/LJGYwiVh/WZaE8cmSBvPJU878PDTRaPV4ixuz5mT9E2Y+hlrP9eQm4SvznjD8TqaSwAgNlE1BfOFlBZ5UjRlOdDfSSSM9MjxLda+TTwFntRum+3irjFLwAzP1O4HCtavxdvJPpZWdVuR6Ku8WH+9Ls30Kp0SzouGkHVSD2udEQm6yFWfSYfMNEfFzg04SRovLkz3NQpEo8evgbxiNYT7pa0m4RMd7VohJn8H/P7Fl7xeEEJdLNKLPEnyxTK0ZH+hPnoNtPqLp+oz8xqefGtvl8ff9cPvXnz2jIS3b6PR+MGEV6eQIOtKuEDCIx3b0kdoSWY9OeglB9eoAl7mUKKZGpH6pKgCLf7QZUL3QSh3jUxp/jZD2TxdKXd0ejBz4DC9CNIvuu95sDnWmwnch+lJU4ObtXW44Xlfal+SYDSD88GYqwFwPhPakFTRhlncoOh2FL7TUcaiopUhYRl8bg+H1yfC0oiciUrT9HC4Jxp0xR/KLwfymFccWObr1c= sspeaks@Seths-MacBook-Pro.local"
      ];
    };

    sspeaks = {
      isNormalUser = true;
      hashedPassword = "!";
      extraGroups = [ "wheel" ];
      openssh.authorizedKeys.keys = config.users.users.root.openssh.authorizedKeys.keys;
    };
  };

  sops = {
    defaultSopsFile = ../../secrets/azure-host.yaml;
    validateSopsFiles = false;
    age = {
      sshKeyPaths = [ "/etc/ssh/ssh_host_ed25519_key" ];
      keyFile = "/var/lib/sops-nix/key.txt";
      generateKey = true;
    };
  };

  assertions = [
    {
      assertion = !config.sops.validateSopsFiles;
      message = "Initial scaffold disables sops file validation until real encrypted secrets are created.";
    }
  ];

  system.stateVersion = "25.05";
}
