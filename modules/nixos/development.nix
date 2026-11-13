{ pkgs, ... }:

{
  environment.systemPackages = with pkgs; [
    # Editors and workstation-wide developer utilities stay globally available.
    zed-editor.fhs
    vscode.fhs
    # Google Antigravity's terminal agent; provides the `agy` executable.
    antigravity-cli
    gemini-cli
    llama-cpp
    jq
  ];
}
