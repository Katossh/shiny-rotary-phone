
{ config, lib, pkgs, inputs, ... }:

{
  imports = [
    ./hardware-configuration.nix
    inputs.noctalia.nixosModules.default
    (inputs.terminal-dotfiles + "/nix/packages.nix")
  ];

  # Bootloader: GRUB (UEFI)
  boot.loader = {
    grub = {
      enable = true;
      device = "nodev";
      efiSupport = true;
      efiInstallAsRemovable = false;
    };

    efi = {
      canTouchEfiVariables = true;
      efiSysMountPoint = "/boot";
    };
  };

  # Disk encryption
  boot.initrd.luks.devices."cryptroot" = {
    device = "/dev/disk/by-uuid/fb18dd0b-4f76-449f-9d00-67cc9d49b4ee";
  };

  # Filesystem
  boot.supportedFilesystems = [ "btrfs" ];

  # Hardware
  boot.kernelPackages = pkgs.linuxPackages_latest;
  
  users.users.katossh.shell = pkgs.zsh;
  # System identity
  networking.hostName = "starforge";
  networking.networkmanager.enable = true;

  time.timeZone = "Europe/Moscow";
  i18n.defaultLocale = "en_US.UTF-8";

  # User
  users.users.katossh = {
    isNormalUser = true;
    extraGroups = [
      "wheel"
      "networkmanager"
    ];
  };

  # Niri compositor
  programs.niri.enable = true;

  # Noctalia shell
  programs.noctalia = {
    enable = true;
    systemd.enable = true;
    recommendedServices.enable = true;
  };
  programs.firefox.enable = true;

  # Login manager
  services.greetd = {
    enable = true;
    settings.default_session = {
      command = "${pkgs.tuigreet}/bin/tuigreet --time --cmd niri-session";
      user = "greeter";
    };
  };

  # Graphics and desktop integration
  hardware.graphics.enable = true;
  security.polkit.enable = true;

  xdg.portal = {
    enable = true;
    extraPortals = with pkgs; [
      xdg-desktop-portal-gtk
    ];
  };

  # Audio
  services.pipewire = {
    enable = true;
    alsa.enable = true;
    pulse.enable = true;
  };

  security.rtkit.enable = true;

  # XWayland compatibility
  environment.systemPackages = with pkgs; [
    xwayland-satellite
    neovim
    vim
    kitty
    git
    fastfetch
  ];

  # Noctalia binary cache
  nix.settings = {
    experimental-features = [
      "nix-command"
      "flakes"
    ];

    extra-substituters = [
      "https://noctalia.cachix.org"
    ];

    extra-trusted-public-keys = [
      "noctalia.cachix.org-1:pCOR47nnMEo5thcxNDtzWpOxNFQsBRglJzxWPp3dkU4="
    ];
  };

  system.stateVersion = "26.05";
}

