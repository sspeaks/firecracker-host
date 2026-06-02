{ vmName, ... }:
{
  sops = {
    defaultSopsFile = ../../vms + "/${vmName}/secrets.yaml";
    validateSopsFiles = false;
    useSystemdActivation = true;

    age = {
      keyFile = "/var/lib/sops-nix/key.txt";
      generateKey = false;
      sshKeyPaths = [ ];
    };
  };
}
