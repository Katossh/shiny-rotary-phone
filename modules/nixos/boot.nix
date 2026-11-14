{
  config,
  lib,
  pkgs,
  ...
}:

let
  rootIsXfs = config.fileSystems."/".fsType == "xfs";
in
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
      # The packaged kernel's dev tree is pruned after its original build.
      # Linux 7.3's bzImage target would rerun X86_DECODER_SELFTEST there, but
      # arch/x86/tools/insn_decoder_test.c is not retained in that tree. The
      # original kernel build already produced vmlinux; skip only this optional
      # build-time test while repackaging the image with module certificates.
      finalKernel =
        (config.boot.kernelPackages.rebuildImage {
          inherit target;
          inherit (config.system) modulesTree;
        }).overrideAttrs
          (old: {
            buildFlags = (old.buildFlags or [ ]) ++ [ "CONFIG_X86_DECODER_SELFTEST=n" ];
          });
      kernelPath = "${finalKernel}/${target}";
    in
    lib.mkAfter ''
      ln -sf -- ${lib.escapeShellArg kernelPath} "$out/kernel"
    '';

  # XFS is not enabled in the initrd by default. Enable its kernel module when
  # the detected root filesystem is XFS; ext4 and Btrfs retain their defaults.
  boot.initrd.supportedFilesystems = lib.mkIf rootIsXfs [ "xfs" ];

  boot = {
    supportedFilesystems = [ "btrfs" ] ++ lib.optionals rootIsXfs [ "xfs" ];

    loader = {
      # The installer detects the EFI partition mounted at /boot and writes
      # its UUID into the generated hardware configuration.
      efi = {
        canTouchEfiVariables = true;
        efiSysMountPoint = "/boot";
      };

      grub.enable = false;

      limine = {
        enable = true;
        efiSupport = true;
        biosSupport = false;
        maxGenerations = 5;
        enableEditor = false;

        # Catppuccin Frappé Sapphire.
        style = {
          interface = {
            branding = "NixOS";
            brandingColor = "85C1DC";
            helpColor = "85C1DC";
            helpColorBright = "85C1DC";
          };

          graphicalTerminal = {
            enable = true;
            palette = "303446;E78284;A6D189;E5C890;8CAAEE;F4B8E4;81C8BE;C6D0F5";
            brightPalette = "626880;E78284;A6D189;E5C890;8CAAEE;F4B8E4;81C8BE;C6D0F5";
            foreground = "C6D0F5";
            background = "303446";
            brightForeground = "C6D0F5";
            brightBackground = "626880";
          };
        };

        # Single-boot profile. Additional operating systems can be added later
        # without tying this base configuration to a fixed partition GUID.
        secureBoot.enable = true;
      };

      timeout = 5;
    };
  };
}
