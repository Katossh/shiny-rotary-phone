{ lib, pkgs, ... }:

{
  # VS Code and its FHS launcher are proprietary; allow only these two
  # Nixpkgs package names rather than enabling all unfree packages.
  nixpkgs.config.allowUnfreePredicate =
    pkg:
    builtins.elem (lib.getName pkg) [
      "vscode"
      "code"
    ];

  environment.systemPackages = with pkgs; [
    zed-editor.fhs
    vscode.fhs
    llama-cpp
    rustc
    cargo
    go
    gcc
  ];
}
