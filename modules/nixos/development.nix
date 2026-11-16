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

    # Python.
    python3
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

    # Everyday development utilities.
    git
    gh
    ripgrep
    fd
    fzf
    just
    tree
    curl
    wget
    unzip
  ];

  # Preserve rust-analyzer access to the Rust standard-library sources.
  environment.sessionVariables.RUST_SRC_PATH = "${pkgs.rustPlatform.rustLibSrc}";
}
