{ lib, pkgs, ... }:

{
  # VS Code is proprietary; permit only its package, not all unfree software.
  nixpkgs.config.allowUnfreePredicate = pkg:
    builtins.elem (lib.getName pkg) [
      "vscode"
      "vscode-fhs"
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
