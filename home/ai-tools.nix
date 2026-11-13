{ inputs, pkgs, ... }:

let
  system = pkgs.stdenv.hostPlatform.system;

  deepseekHarnessDesktop = pkgs.appimageTools.wrapType2 {
    pname = "deepseek-harness-desktop";
    version = "0.31.5";
    src = pkgs.fetchurl {
      url = "https://github.com/dsh-tauri/deepseek-harness-desktop/releases/download/v0.31.5/Deepseek.Harness.Desktop_0.31.5_amd64.AppImage";
      sha256 = "6cb9d703236f452c0a811c809b1e0570554ef6e4d0576b1659e99225703b9db6";
    };
  };

  # The upstream CLI is distributed through npm. Keep it as a Nix-managed
  # launcher; npx fetches the published CLI on first invocation and caches it
  # in the user's npm cache.
  deepseekHarnessCli = pkgs.writeShellApplication {
    name = "dsh";
    runtimeInputs = [ pkgs.nodejs ];
    text = ''
      exec npx --yes @deepseek-ai/dsh "$@"
    '';
  };
in
{
  home.packages = [
    # Official OpenCode Desktop; the existing 'opencode' package remains the CLI.
    inputs.opencode-desktop-nix.packages.${system}.opencode-desktop

    # Hermes Agent CLI and its separate desktop application.
    inputs.hermes-agent.packages.${system}.default
    inputs.hermes-agent.packages.${system}.desktop

    # DeepSeek Harness desktop and its standalone upstream CLI launcher.
    deepseekHarnessDesktop
    deepseekHarnessCli
  ];
}
