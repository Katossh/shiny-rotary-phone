{
  config,
  lib,
  pkgs,
  ...
}:

{
  environment.systemPackages = [ pkgs.sbctl ];

  # Embed the certificates for signed kernel modules in the kernel image.
  # Nixpkgs' kernel-module-verification test uses the same rebuildImage
  # integration to make those module signatures trusted by the running kernel.
  system.systemBuilderCommands =
    let
      target =
        if pkgs.stdenv.hostPlatform.isAarch64 then
          "vmlinuz.efi"
        else
          config.boot.kernelPackages.kernel.target;
      finalKernel = config.boot.kernelPackages.rebuildImage {
        inherit target;
        inherit (config.system) modulesTree;
      };
      kernelPath = "${finalKernel}/${target}";
    in
    lib.mkAfter ''
      ln -sf -- ${lib.escapeShellArg kernelPath} "$out/kernel"
    '';

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

        # Sign Limine's EFI executable with the sbctl key provisioned locally.
        # Keep the private key material out of the repository.
        secureBoot.enable = true;
      };

      timeout = 5;
    };

    supportedFilesystems = [ "btrfs" ];
  };
}
