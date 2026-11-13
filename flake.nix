{
  description = "NixOS workstation configuration with Niri and Noctalia";

  nixConfig = {
    extra-substituters = [
      "https://noctalia.cachix.org"
      "https://ezkea.cachix.org"
    ];
    extra-trusted-public-keys = [
      "noctalia.cachix.org-1:pCOR47nnMEo5thcxNDtzWpOxNFQsBRglJzxWPp3dkU4="
      "ezkea.cachix.org-1:ioBmUbJTZIKsHmWWXPe1FSFbeVe+afhfgqgTSNd34eI="
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

    # Use the matching 26.11 branch of the community Genshin launcher module.
    aagl = {
      url = "github:ezKEa/aagl-gtk-on-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # Official Hermes Agent flake: provides the CLI and its desktop application.
    hermes-agent = {
      url = "github:NousResearch/hermes-agent";
      inputs.nixpkgs.follows = "nixpkgs";
      inputs.home-manager.follows = "home-manager";
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

      devShells.${system} = {
        # Keep the default shell lightweight: CI uses it for Nix static analysis.
        default = pkgs.mkShell {
          packages = with pkgs; [
            deadnix
            statix
          ];
        };

        # General-purpose toolchain for experiments and projects without their
        # own flake. Project flakes can still pin narrower or different versions.
        general = pkgs.mkShell {
          packages = with pkgs; [
            # Rust
            rustc
            cargo
            rustfmt
            clippy
            rust-analyzer

            # Python
            python3
            uv
            ruff
            basedpyright

            # Go
            go
            gopls
            golangci-lint

            # JavaScript and TypeScript
            nodejs
            pnpm
            typescript
            typescript-language-server
            eslint
            prettier

            # C and C++
            gcc
            clang
            clang-tools
            cmake
            ninja
            gnumake
            pkg-config
            gdb

            # Nix and shell tooling
            nixd
            nixfmt
            deadnix
            statix
            shellcheck
            shfmt

            # Everyday development utilities
            git
            gh
            jq
            ripgrep
            fd
            fzf
            just
            tree
            curl
            wget
            unzip
          ];

          # Native libraries commonly needed by Rust crates and Python wheels.
          buildInputs = with pkgs; [
            libffi
            openssl
            sqlite
            zlib
          ];

          # Make the standard library sources available to rust-analyzer.
          RUST_SRC_PATH = "${pkgs.rustPlatform.rustLibSrc}";
        };
      };

      nixosConfigurations = {
        inherit workstation;

        # Never publish a kernel compiled with the GitHub runner's CPU features
        # as the native workstation kernel.
        workstation-ci = workstation.extendModules {
          modules = [
            {
              starforge.kernel.nativeCpuOptimization.enable = false;
            }
          ];
        };
      };
    };
}
