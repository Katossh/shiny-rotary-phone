{ pkgs, ... }:

{
  environment.systemPackages = with pkgs; [
    # Editors and workstation-wide developer utilities stay globally available.
    zed-editor.fhs
    vscode.fhs
    # Keep Antigravity IDE extensions with bundled native tools in an FHS environment.
    antigravity-ide-fhs
    llama-cpp
    jq
  ];
}
