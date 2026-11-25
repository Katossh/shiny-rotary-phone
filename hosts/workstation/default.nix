{ config, inputs, ... }:

{
  networking.hostName = "workstation";

  # Host-specific build parallelism: this workstation has 12 logical CPU
  # threads. Reusable Nix modules leave this at the Nix default.
  nix.settings.cores = 12;

  # Expose a manually started llama.cpp server only to IPv4 clients on the
  # home Wi-Fi LAN. No llama.cpp service is enabled by default. Match both the
  # ingress interface and source subnet so non-LAN sources on this NIC are not
  # accepted by an interface-only rule.
  networking.firewall.extraCommands = ''
    iptables -A nixos-fw \
      -i wlp7s0 \
      -s 192.168.0.0/24 \
      -p tcp --dport 1234 \
      -j nixos-fw-accept

    # LocalSend uses TCP for transfers and UDP for LAN device discovery.
    # Permit both only from clients on the home Wi-Fi subnet.
    iptables -A nixos-fw \
      -i wlp7s0 \
      -s 192.168.0.0/24 \
      -p tcp --dport 53317 \
      -j nixos-fw-accept

    iptables -A nixos-fw \
      -i wlp7s0 \
      -s 192.168.0.0/24 \
      -p udp --dport 53317 \
      -j nixos-fw-accept
  '';

  # The single interactive account shared by NixOS and Home Manager.
  starforge.user.username = "katossh";

  imports = [
    ./hardware-configuration.nix
    ./hardware.nix
    ./displays.nix

    ../../modules/nixos/nixpkgs.nix
    ../../modules/nixos/xray.nix
    ../../modules/nixos/nix.nix
    ../../modules/nixos/boot.nix
    ../../modules/nixos/scheduling.nix
    ../../modules/nixos/locale.nix

    ../../modules/nixos/networking.nix
    ../../modules/nixos/tor.nix
    ../../modules/nixos/security.nix
    ../../modules/nixos/apparmor.nix
    ../../modules/security/bubblewrap
    ../../modules/nixos/usbguard.nix
    ../../modules/nixos/users.nix

    ../../modules/nixos/hardware.nix
    ../../modules/nixos/storage.nix
    ../../modules/nixos/snapshots.nix
    ../../modules/nixos/memory.nix
    ../../modules/nixos/power.nix

    ../../modules/nixos/audio.nix
    ../../modules/nixos/fonts.nix
    ../../modules/nixos/desktop.nix
    ../../modules/nixos/development.nix
    ../../modules/nixos/media.nix
    ../../modules/nixos/gaming.nix
    ../../modules/nixos/terminal.nix
    ../../modules/nixos/containers.nix
    ../../modules/nixos/virtualisation.nix
    ../../modules/nixos/network-tools.nix
    ../../modules/nixos/observability.nix
  ];

  home-manager = {
    useGlobalPkgs = true;
    useUserPackages = true;
    backupFileExtension = "hm-backup";

    extraSpecialArgs = {
      inherit inputs;
      starforgeUsername = config.starforge.user.username;
    };

    users.${config.starforge.user.username} = import ../../home;
  };

  # Preserve compatibility defaults from the original installation.
  system.stateVersion = "26.05";
}
