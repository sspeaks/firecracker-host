{
  description = "NixOS Firecracker microVM fleet with sops-nix secrets";

  nixConfig = {
    extra-substituters = [ "https://microvm.cachix.org" ];
    extra-trusted-public-keys = [
      "microvm.cachix.org-1:oXnBc6hRE3eX5rSYdRyMYXnfzcCxC7yKPTbZXALsqys="
    ];
  };

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

    microvm = {
      url = "github:microvm-nix/microvm.nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    sops-nix = {
      url = "github:Mic92/sops-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    disko = {
      url = "github:nix-community/disko";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    impermanence = {
      url = "github:nix-community/impermanence";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs =
    inputs@{
      self,
      nixpkgs,
      microvm,
      sops-nix,
      disko,
      impermanence,
      ...
    }:
    let
      lib = nixpkgs.lib;
      systems = [
        "x86_64-linux"
        "aarch64-linux"
      ];
      forAllSystems = lib.genAttrs systems;
      inventory = import ./lib/inventory.nix;

      mkHypervisor =
        system:
        lib.nixosSystem {
          inherit system;
          specialArgs = {
            inherit
              inputs
              inventory
              self
              ;
            targetSystem = system;
          };
          modules = [
            microvm.nixosModules.host
            sops-nix.nixosModules.sops
            impermanence.nixosModules.impermanence
            ./modules/host/impermanence.nix
            ./hosts/hypervisor
            { nixpkgs.hostPlatform = lib.mkForce system; }
          ];
        };

      mkAzureHypervisor =
        system:
        lib.nixosSystem {
          inherit system;
          specialArgs = {
            inherit
              inputs
              inventory
              self
              ;
            targetSystem = system;
          };
          modules = [
            disko.nixosModules.disko
            microvm.nixosModules.host
            sops-nix.nixosModules.sops
            impermanence.nixosModules.impermanence
            ./modules/host/impermanence.nix
            ./hosts/azure-hypervisor
            { nixpkgs.hostPlatform = lib.mkForce system; }
          ];
        };

      mkVmSystem =
        system: vmName: vm:
        lib.nixosSystem {
          inherit system;
          specialArgs = {
            inherit
              inputs
              inventory
              self
              vm
              vmName
              ;
          };
          modules = [
            microvm.nixosModules.microvm
            sops-nix.nixosModules.sops
            impermanence.nixosModules.impermanence
            ./modules/vm/base-firecracker.nix
            ./modules/vm/impermanence.nix
            ./modules/vm/networking.nix
            ./modules/vm/sops-guest.nix
            (./vms + "/${vmName}")
            { firecracker.impermanence.enable = vm.impermanence.enable or true; }
          ];
        };
    in
    {
      nixosModules = {
        firecracker-vm = ./modules/vm/base-firecracker.nix;
        host-impermanence = ./modules/host/impermanence.nix;
        vm-impermanence = ./modules/vm/impermanence.nix;
        vm-networking = ./modules/vm/networking.nix;
        vm-sops = ./modules/vm/sops-guest.nix;
      };

      nixosConfigurations = {
        hypervisor = mkHypervisor "x86_64-linux";
        azure-hypervisor = mkAzureHypervisor "x86_64-linux";
      }
      // lib.mapAttrs (mkVmSystem "x86_64-linux") inventory.vms
      // {
        hypervisor-aarch64 = mkHypervisor "aarch64-linux";
      }
      // lib.mapAttrs' (
        name: vm: lib.nameValuePair "${name}-aarch64" (mkVmSystem "aarch64-linux" name vm)
      ) inventory.vms;

      devShells = forAllSystems (
        system:
        let
          pkgs = nixpkgs.legacyPackages.${system};
        in
        {
          default = pkgs.mkShell {
            packages = with pkgs; [
              age
              nixos-anywhere
              nixfmt
              sops
              ssh-to-age
            ];
          };
        }
      );

      formatter = forAllSystems (system: nixpkgs.legacyPackages.${system}.nixfmt);

      apps = forAllSystems (
        system:
        let
          pkgs = nixpkgs.legacyPackages.${system};
          hypervisorAttr = if system == "x86_64-linux" then "hypervisor" else "hypervisor-aarch64";
        in
        {
          run-hypervisor-vm = {
            type = "app";
            program = "${
              pkgs.writeShellApplication {
                name = "run-hypervisor-vm";
                runtimeInputs = [
                  pkgs.coreutils
                  pkgs.gnugrep
                  pkgs.nix
                ];
                text = ''
                  REPO_ROOT="''${REPO_ROOT:-$PWD}"
                  export HYPERVISOR_NIX_ATTR=".#nixosConfigurations.${hypervisorAttr}.config.system.build.vm"
                  exec ${./scripts/run-hypervisor-vm.sh} "$@"
                '';
              }
            }/bin/run-hypervisor-vm";
          };
        }
      );
    };
}
