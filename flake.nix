{
  description = "Starforge NixOS workstation with Niri and Noctalia";

  nixConfig = {
    extra-substituters = [ "https://noctalia.cachix.org" ];
    extra-trusted-public-keys = [
      "noctalia.cachix.org-1:pCOR47nnMEo5thcxNDtzWpOxNFQsBRglJzxWPp3dkU4="
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

    # Keep Noctalia's own pinned nixpkgs: this is required for Cachix hits.
    noctalia.url = "github:noctalia-dev/noctalia/cachix";

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
    in
    {
      formatter.${system} = pkgs.nixfmt;

      # Keep Nix analysis tools on the same locked Nixpkgs revision as the host.
      devShells.${system}.default = pkgs.mkShell {
        packages = with pkgs; [
          deadnix
          statix
        ];
      };

      nixosConfigurations.starforge = nixpkgs.lib.nixosSystem {
        inherit system;

        specialArgs = {
          inherit inputs;
        };

        modules = [
          home-manager.nixosModules.home-manager
          ./hosts/starforge
        ];
      };
    };
}
