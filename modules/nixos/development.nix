{ pkgs, ... }:

{
  environment.systemPackages = with pkgs; [
    # Editors and workstation-wide developer utilities stay globally available.
    zed-editor.fhs
    vscode.fhs
    llama-cpp
    jq
  ];
}
