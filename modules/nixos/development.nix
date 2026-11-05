{ pkgs, ... }:

{
  environment.systemPackages = with pkgs; [
    zed-editor.fhs
    vscode.fhs
    llama-cpp
    rustc
    cargo
    go
    gcc
    clang
    jq
  ];
}
