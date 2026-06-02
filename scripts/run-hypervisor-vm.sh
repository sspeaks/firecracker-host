#!/usr/bin/env bash
set -euo pipefail

repo_root="${REPO_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"
cd "$repo_root"

host_arch="$(uname -m)"
case "$host_arch" in
  aarch64|arm64)
    default_hypervisor_attr="hypervisor-aarch64"
    ;;
  *)
    default_hypervisor_attr="hypervisor"
    ;;
esac

build_attr="${HYPERVISOR_NIX_ATTR:-.#nixosConfigurations.${default_hypervisor_attr}.config.system.build.vm}"
disk_image="${NIX_DISK_IMAGE:-$repo_root/.local/state/hypervisor-vm.qcow2}"

if [[ "${1:-}" == "--build-only" || "${1:-}" == "--no-run" ]]; then
  nix build "$build_attr"
  echo "Built ./result/bin/run-hypervisor-vm"
  exit 0
fi

if [[ "$(uname -s)" != "Linux" ]]; then
  cat >&2 <<'EOF'
This runner needs a Linux machine with KVM and nested virtualization.

On macOS or other non-Linux hosts, use a Linux builder/host and run:

  nix run .#run-hypervisor-vm

EOF
  exit 1
fi

if [[ ! -e /dev/kvm ]]; then
  cat >&2 <<'EOF'
/dev/kvm is missing. Enable hardware virtualization in firmware and load KVM:

  sudo modprobe kvm_intel  # Intel x86_64
  sudo modprobe kvm_amd    # AMD x86_64
  sudo modprobe kvm        # aarch64 / generic

EOF
  exit 1
fi

if [[ ! -r /dev/kvm || ! -w /dev/kvm ]]; then
  cat >&2 <<'EOF'
The current user cannot read/write /dev/kvm.

Add the user to the kvm group, log out, and log back in:

  sudo usermod -aG kvm "$USER"

EOF
  exit 1
fi

if [[ "$host_arch" == "aarch64" || "$host_arch" == "arm64" ]]; then
  if grep -Eq '(^|[[:space:]])kvm-arm\.mode=nested($|[[:space:]])' /proc/cmdline 2>/dev/null; then
    nested_state="Y"
  else
    nested_state="unknown"
  fi
else
  nested_state="$(
    for path in /sys/module/kvm_intel/parameters/nested /sys/module/kvm_amd/parameters/nested; do
      if [[ -r "$path" ]]; then
        cat "$path"
        exit 0
      fi
    done
    echo unknown
  )"
fi

case "$nested_state" in
  Y|y|1)
    ;;
  unknown)
    if [[ "$host_arch" == "aarch64" || "$host_arch" == "arm64" ]]; then
      cat >&2 <<'EOF'
Note: could not confirm nested KVM on aarch64.
The outer NixOS VM may boot, but Firecracker guests inside it require nested KVM.

On aarch64, nested KVM depends on CPU, firmware, kernel, and EL2 exposure rather
than kvm_intel/kvm_amd module parameters. On NixOS, enable it on supported
bare-metal ARM hosts with:

  boot.kernelParams = [ "kvm-arm.mode=nested" ];

Regular virtualized ARM cloud instances often cannot expose nested KVM because
the provider hypervisor already owns EL2.

EOF
    else
      cat >&2 <<EOF
Warning: nested KVM does not appear to be enabled (nested=$nested_state).
The outer NixOS VM may boot, but Firecracker guests inside it may fail.

Intel example:
  echo 'options kvm_intel nested=1' | sudo tee /etc/modprobe.d/kvm-intel.conf

AMD example:
  echo 'options kvm_amd nested=1' | sudo tee /etc/modprobe.d/kvm-amd.conf

Reload KVM modules or reboot after changing this.

EOF
    fi
    ;;
  *)
    cat >&2 <<EOF
Warning: nested KVM is disabled (nested=$nested_state).
The outer NixOS VM may boot, but Firecracker guests inside it may fail.

Intel example:
  echo 'options kvm_intel nested=1' | sudo tee /etc/modprobe.d/kvm-intel.conf

AMD example:
  echo 'options kvm_amd nested=1' | sudo tee /etc/modprobe.d/kvm-amd.conf

aarch64:
  boot.kernelParams = [ "kvm-arm.mode=nested" ];

Reload KVM modules or reboot after changing this.

EOF
    ;;
esac

mkdir -p "$(dirname "$disk_image")"

echo "Building hypervisor VM..."
nix build "$build_attr"

cat <<EOF

Starting the nested hypervisor VM.

Outer VM login:
  console: root / root
  ssh:     ssh -p 2222 root@localhost

Inside the outer VM, check the Firecracker guests:
  microvm -l
  systemctl status microvm@web-01.service
  journalctl -u microvm@web-01.service -f

Persistent outer VM disk:
  $disk_image

EOF

export NIX_DISK_IMAGE="$disk_image"
exec ./result/bin/run-hypervisor-vm
