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

        # Secure Boot is intentionally staged separately. First test the new
        # Limine boot path for both operating systems; enroll keys only after
        # that succeeds and the recovery path has been verified.
        secureBoot.enable = false;
      };

      timeout = 5;
    };

    supportedFilesystems = [ "btrfs" ];

    # Keep the original kernel policy during the structural refactor.
    kernelPackages = pkgs.linuxPackages_latest;
  };

  environment.systemPackages = [ pkgs.sbctl ];
}
