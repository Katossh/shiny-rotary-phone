{ pkgs, ... }:

{
  # Primary development toolchains are globally available so editors launched
  # from the desktop session can discover compilers and language servers.
  # Project-specific or incompatible dependencies belong in project devShells.
  environment.systemPackages = with pkgs; [
    # Editors and workstation-wide developer utilities.
    zed-editor.fhs
    vscode.fhs
    llama-cpp
    jq

    # Rust.
    rustc
    cargo
    rustfmt
    clippy
    rust-analyzer

    # Python (python3 is already provided by terminal-dotfiles' Nix package manifest).
    uv
    ruff
    basedpyright

    # Go.
    go
    gopls
    golangci-lint

    # JavaScript and TypeScript.
    nodejs
    pnpm
    typescript
    typescript-language-server
    eslint
    prettier

    # C and C++.
    gcc
    clang
    clang-tools
    cmake
    ninja
    gnumake
    pkg-config
    gdb

    # Nix and shell tooling.
    nixd
    nixfmt
    deadnix
    statix
    shellcheck
    shfmt

    # Everyday utilities not already owned by terminal-dotfiles or Home Manager.
    just
    tree
    wget
  ];

  # Preserve rust-analyzer access to the Rust standard-library sources.
  environment.sessionVariables = {
    RUST_SRC_PATH = "${pkgs.rustPlatform.rustLibSrc}";

    # Nixpkgs' VS Code wrapper enables Electron's native Wayland backend when
    # this is set and WAYLAND_DISPLAY is present. This avoids relying on XWayland
    # under Niri while remaining harmless in non-Wayland sessions.
    NIXOS_OZONE_WL = "1";
  };
}
