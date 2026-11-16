{
  description = "NixOS workstation configuration with Niri and Noctalia";

  nixConfig = {
    extra-substituters = [
      "https://noctalia.cachix.org"
      "https://ezkea.cachix.org"
      "https://cache.lantian.pub/lantian"
    ];
    extra-trusted-public-keys = [
      "noctalia.cachix.org-1:pCOR47nnMEo5thcxNDtzWpOxNFQsBRglJzxWPp3dkU4="
      "ezkea.cachix.org-1:ioBmUbJTZIKsHmWWXPe1FSFbeVe+afhfgqgTSNd34eI="
      "lantian:WVGO7vsRMSEN+h7Lp7kv6SAmrkEXgUGbbXm7jMDjBuQ="
    ];
  };

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    nixos-hardware = {
      url = "github:NixOS/nixos-hardware";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # Use the upstream release branch and its pinned Nixpkgs for binary-cache compatibility.
    nix-cachyos-kernel.url = "github:xddxdd/nix-cachyos-kernel/release";

    # Keep Noctalia's own pinned nixpkgs: this is required for Cachix hits.
    noctalia.url = "github:noctalia-dev/noctalia/cachix";

    # Use the matching 26.11 branch of the community Genshin launcher module.
    aagl = {
      url = "github:ezKEa/aagl-gtk-on-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    terminal-dotfiles = {
      url = "github:Katossh/terminal-dotfiles";
      flake = false;
    };
  };

  outputs =
    inputs@{
      nixpkgs,
      home-manager,
      ...
    }:
    let
      system = "x86_64-linux";
      pkgs = nixpkgs.legacyPackages.${system};

      workstation = nixpkgs.lib.nixosSystem {
        inherit system;

        specialArgs = {
          inherit inputs;
        };

        modules = [
          home-manager.nixosModules.home-manager
          ./hosts/workstation
        ];
      };
    in
    {
      formatter.${system} = pkgs.nixfmt;

      # Keep the lightweight default shell for CI's Nix static analysis.
      # The workstation's general development toolchain is installed globally
      # by modules/nixos/development.nix instead of a second interactive shell.
      devShells.${system}.default = pkgs.mkShell {
        packages = with pkgs; [
          deadnix
          statix
        ];
      };

      nixosConfigurations = {
        inherit workstation;
      };
    };
}
