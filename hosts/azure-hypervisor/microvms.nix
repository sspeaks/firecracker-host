{
  config,
  inventory,
  lib,
  self,
  targetSystem ? "x86_64-linux",
  ...
}:
let
  vmNames = builtins.attrNames inventory.vms;
  values = f: map (name: f inventory.vms.${name}) vmNames;
  unique = xs: builtins.length xs == builtins.length (lib.unique xs);
  configSuffix = if targetSystem == "x86_64-linux" then "" else "-aarch64";
in
{
  assertions = [
    {
      assertion = builtins.all (name: builtins.stringLength inventory.vms.${name}.tap <= 15) vmNames;
      message = "Every Firecracker TAP interface name must be at most 15 characters.";
    }
    {
      assertion = unique (values (vm: vm.tap));
      message = "Every VM TAP interface name must be unique.";
    }
    {
      assertion = unique (values (vm: vm.mac));
      message = "Every VM MAC address must be unique.";
    }
    {
      assertion = unique (values (vm: vm.ipv4));
      message = "Every VM IPv4 address must be unique.";
    }
    {
      assertion = unique (values (vm: vm.vsockCid));
      message = "Every VM vsock CID must be unique.";
    }
  ];

  microvm.stateDir = "/var/lib/microvms";

  microvm.vms = lib.mapAttrs' (
    name: _vm:
    lib.nameValuePair "${name}${configSuffix}" {
      flake = self;
      autostart = true;
      restartIfChanged = true;
    }
  ) inventory.vms;
}
