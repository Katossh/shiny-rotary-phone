{ pkgs, ... }:

{
  boot = {
    loader = {
      # Keep the existing FAT32 /boot partition. Limine installs its EFI
      # executable there and creates a dedicated UEFI boot entry.
      efi = {
        canTouchEfiVariables = true;
        efiSysMountPoint = "/boot";
      };

      grub.enable = false;

      limine = {
        enable = true;
        efiSupport = true;
        biosSupport = false;

        # Retain several known-good NixOS generations without allowing /boot
        # to grow indefinitely.
        maxGenerations = 5;

        # The Limine editor permits changing the kernel command line at boot.
        # Keep it disabled now so the configuration is ready for Secure Boot.
        enableEditor = false;

        # Windows has its own ESP on the same NVMe disk. Limine can chainload
        # its Microsoft-signed Boot Manager directly by GPT partition GUID.
        extraEntries = ''
          /Windows 11
            protocol: efi
            path: guid(68a6f3c1-1eee-4845-8c3e-7108cec34c4a):/EFI/Microsoft/Boot/bootmgfw.efi
        '';

        # Limine Secure Boot signing and config/checksum validation are enabled.
        # Create and enroll the host keys manually before applying this
        # generation. Never create or enroll keys automatically during rebuild.
        secureBoot = {
          enable = true;
          autoGenerateKeys = false;
          autoEnrollKeys.enable = false;
        };
      };

      timeout = 5;
    };

    supportedFilesystems = [ "btrfs" ];

    # Use Nixpkgs' default maintained LTS kernel set instead of latest mainline.
    kernelPackages = pkgs.linuxPackages;
  };

  environment.systemPackages = [ pkgs.sbctl ];
}
