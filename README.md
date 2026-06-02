# NixOS Firecracker microVM fleet

This repository defines a Nix flake for one NixOS hypervisor host and a small fleet of Firecracker-backed NixOS microVMs managed with [`microvm.nix`](https://github.com/microvm-nix/microvm.nix) and [`sops-nix`](https://github.com/Mic92/sops-nix).

## Architecture

- `flake.nix` pins `nixpkgs`, `microvm.nix`, `sops-nix`, and `disko`.
- Flake outputs support both `x86_64-linux` and `aarch64-linux`. Firecracker guests must use the same CPU architecture as their host.
- `hosts/hypervisor/` defines the physical host.
- `hosts/azure-hypervisor/` defines an Azure VM host profile for `nixos-anywhere`.
- `lib/inventory.nix` is the source of truth for VM names, TAP interfaces, MACs, IPs, vsock CIDs, CPU, memory, and disk sizes.
- `modules/vm/` contains reusable Firecracker guest defaults.
- `vms/<name>/` contains per-VM service configuration and encrypted sops files.
- `.sops.yaml` defines age recipients for host and VM secret files.
- `secrets/` contains host-level encrypted files.

The host uses flake-referenced microVMs:

```nix
microvm.vms.<name> = {
  flake = self;
  autostart = true;
  restartIfChanged = true;
};
```

Host rebuilds are the source of truth for VM deployment. Each `nixos-rebuild switch` refreshes the declared VM runners from the flake source used for that rebuild and restarts VMs whose guest configuration changed. This avoids a separate mutable `/etc/nixos` checkout on the host.

The `microvm -u` command can still rebuild a VM from the flake source stored by the currently deployed host generation, but it is a fallback/debugging path rather than the normal deployment path.

Deploy VM changes with the host:

```bash
nixos-rebuild switch --flake .#hypervisor --target-host root@hypervisor
```

## Firecracker constraints

Firecracker under `microvm.nix` is intentionally minimal:

- TAP networking only.
- Block volumes for writable state.
- Optional vsock for host-to-guest communication.
- No 9p or virtiofs directory shares.
- No `microvm.credentialFiles`.
- No memory ballooning or device passthrough.

Because Firecracker cannot share `/run/secrets` or `/nix/store` from the host, each guest uses a self-contained store disk and decrypts its own secrets locally.

## Secrets

Guest secrets are managed with guest-local `sops-nix`.

- Encrypted files live at `vms/<name>/secrets.yaml`.
- The guest age key is expected at `/var/lib/sops-nix/key.txt`.
- `/var` is backed by a persistent Firecracker block volume.
- Plaintext secrets are written by `sops-nix` to `/run/secrets` at activation time.

Bootstrap options:

1. Pre-generate one age key per VM, add the public keys to `.sops.yaml`, encrypt the VM secrets, and copy each private key onto the guest's `/var` volume before first boot.
2. Let the VM generate a persistent SSH host key, convert the public key with `ssh-to-age`, add it to `.sops.yaml`, re-encrypt secrets, and redeploy.
3. Implement a vsock-based host secret agent if you need dynamic key delivery.

The scaffold sets `sops.validateSopsFiles = false` so the flake can evaluate before real encrypted files exist. Remove that override after replacing the placeholder secret files with encrypted SOPS files.

## Networking

The default host topology is bridge + NAT:

- Host bridge: `vmbr0`
- Host bridge address: `10.0.0.1/24`
- VM addresses: static DHCP leases from `lib/inventory.nix`
- VM TAP names: `vm-*`
- External interface placeholder: `eno1`

Update `lib/inventory.nix` before deploying if your uplink is not `eno1`.

The Azure host profile keeps the same internal bridge and VM subnet, but NATs through `eth0` because Azure disables predictable interface names through `azure-common.nix`.

## Azure deployment with nixos-anywhere

The `azure-hypervisor` host is intended for Azure Generation 2 VMs created with Security type set to Standard. Trusted Launch and Secure Boot can block the kexec installer that `nixos-anywhere` uses.

Before deployment:

1. Verify the temporary Azure Linux VM is reachable over SSH and the user has passwordless sudo or root access.
2. Verify the OS disk path with `lsblk`; the default disko config targets `/dev/sda`.
3. Verify the VM size exposes `/dev/kvm` if the host will run Firecracker guests.
4. Replace the placeholder root SSH key in `hosts/azure-hypervisor/default.nix`.
5. Replace SOPS placeholders in `.sops.yaml` and `secrets/azure-host.yaml`, or keep validation disabled until after first boot.

Deploy from a Linux builder or build on the remote Azure VM:

```bash
nix run github:nix-community/nixos-anywhere -- \
  --flake .#azure-hypervisor \
  --target-host azureuser@<azure-public-ip> \
  --build-on remote \
  --debug
```

If the host SSH key is pre-generated for SOPS bootstrapping, stage it in an `--extra-files` directory under `etc/ssh/ssh_host_ed25519_key` and include that flag in the deployment command.

After first boot, confirm SSH access, Azure runtime services, and the Firecracker host bridge:

```bash
ssh root@<azure-public-ip> 'systemctl status waagent; ip link show vmbr0; systemctl list-units "microvm@*"'
```

## Common commands

Enter the development shell:

```bash
nix develop
```

Run a local nested hypervisor VM:

```bash
nix run .#run-hypervisor-vm
# or:
./scripts/run-hypervisor-vm.sh
```

Inspect the flake:

```bash
nix flake show
```

Evaluate the hypervisor configuration:

```bash
nix eval .#nixosConfigurations.hypervisor.config.networking.hostName
nix eval .#nixosConfigurations.hypervisor.config.nixpkgs.hostPlatform.system
```

Evaluate the aarch64 hypervisor configuration:

```bash
nix eval .#nixosConfigurations.hypervisor-aarch64.config.networking.hostName
nix eval .#nixosConfigurations.hypervisor-aarch64.config.nixpkgs.hostPlatform.system
```

Deploy the host:

```bash
nixos-rebuild switch --flake .#hypervisor --target-host root@hypervisor
```

For an aarch64 host, use `.#hypervisor-aarch64`. The aarch64 VM configuration keys are suffixed with `-aarch64`, for example `web-01-aarch64`.

The rebuild also updates and restarts changed microVMs. For ad hoc debugging, update a single VM from the deployed generation's stored flake source:

```bash
microvm -u web-01 -R
```

Check VM status on the host:

```bash
microvm -l
systemctl status microvm@web-01.service
journalctl -u microvm@web-01.service -f
```

## Running the hypervisor as a VM

The flake includes a NixOS VM variant for the `hypervisor` host. It boots the host under QEMU and replaces the production flake-referenced guests with lightweight inline Firecracker smoke guests named from `lib/inventory.nix`.

This is meant for Linux development machines with KVM and nested virtualization enabled. It is not expected to run directly on macOS because Firecracker requires `/dev/kvm`.

Start it with:

```bash
nix run .#run-hypervisor-vm
```

Build the VM runner without starting it:

```bash
./scripts/run-hypervisor-vm.sh --build-only
```

The script checks:

- host OS is Linux
- `/dev/kvm` exists
- current user can read and write `/dev/kvm`
- nested KVM appears enabled on x86_64, or reports the aarch64 nested-KVM requirements

The outer VM uses a persistent disk at:

```text
.local/state/hypervisor-vm.qcow2
```

Override it if needed:

```bash
NIX_DISK_IMAGE=/tmp/hypervisor-vm.qcow2 nix run .#run-hypervisor-vm
```

Outer VM access:

```bash
# Console login
root / root

# SSH from the host machine
ssh -p 2222 root@localhost
```

Inside the outer VM, inspect the Firecracker guests:

```bash
microvm -l
systemctl status microvm@web-01.service
systemctl status microvm@db-01.service
systemctl status microvm@mon-01.service
journalctl -u microvm@web-01.service -f
```

The nested VM variant intentionally uses lightweight smoke guest configs instead of the production guest configs. That avoids requiring real encrypted secrets or VM age-key bootstrap just to test that the host can start Firecracker guests.

If Firecracker guests fail inside the outer VM, check nested virtualization:

### x86_64

```bash
cat /sys/module/kvm_intel/parameters/nested  # Intel: should be Y or 1
cat /sys/module/kvm_amd/parameters/nested    # AMD: should be Y or 1
```

Enable it with a host-level KVM module option and reboot:

```bash
# Intel
echo 'options kvm_intel nested=1' | sudo tee /etc/modprobe.d/kvm-intel.conf

# AMD
echo 'options kvm_amd nested=1' | sudo tee /etc/modprobe.d/kvm-amd.conf
```

### aarch64

Direct Firecracker on a native aarch64 Linux host only needs accessible `/dev/kvm`. This nested hypervisor VM test is stricter because it runs Firecracker inside an outer QEMU VM, so the outer VM also needs nested KVM/EL2 support.

On supported bare-metal ARM hosts, enable nested KVM with a kernel parameter:

```nix
boot.kernelParams = [ "kvm-arm.mode=nested" ];
```

Then reboot and confirm the parameter is present:

```bash
grep -E '(^|[[:space:]])kvm-arm\.mode=nested($|[[:space:]])' /proc/cmdline
```

Many virtualized ARM cloud instances cannot expose nested KVM because the provider hypervisor already owns EL2.

## Before real deployment

1. Replace `hosts/hypervisor/hardware-configuration.nix` with the file generated for the physical host.
2. Update `lib/inventory.nix` for the real network, VM sizes, and VM count.
3. Generate real age keys and update `.sops.yaml`.
4. Replace placeholder `*.yaml` files with encrypted SOPS files.
5. Remove or reconsider `sops.validateSopsFiles = false`.
6. Commit `flake.lock` after the first successful `nix flake update`.
7. For aarch64 deployments, use the `-aarch64` flake configuration keys and replace the placeholder hardware configuration with one generated on the target ARM host.
