{ inputs, pkgs, ... }:

let
  deepseekHarnessDesktop = pkgs.appimageTools.wrapType2 {
    pname = "deepseek-harness-desktop";
    version = "0.31.5";
    src = pkgs.fetchurl {
      url = "https://github.com/dsh-tauri/deepseek-harness-desktop/releases/download/v0.31.5/Deepseek.Harness.Desktop_0.31.5_amd64.AppImage";
      sha256 = "6cb9d703236f452c0a811c809b1e0570554ef6e4d0576b1659e99225703b9db6";
    };
  };

  # The upstream CLI is published on npm. npx installs it on first use and
  # keeps its download in the user's npm cache, outside the immutable store.
  deepseekHarnessCli = pkgs.writeShellApplication {
    name = "dsh";
    runtimeInputs = [ pkgs.nodejs ];
    text = ''
      exec npx --yes @deepseek-ai/dsh "$@"
    '';
  };
in
{
  imports = [
    inputs.hermes-agent.homeManagerModules.default
  ];

  home.packages = [
    # Official OpenCode Desktop; the existing 'opencode' package remains the CLI.
    inputs.opencode-desktop-nix.packages.${pkgs.stdenv.hostPlatform.system}.opencode-desktop

    # DeepSeek Harness desktop and its standalone upstream CLI launcher.
    deepseekHarnessDesktop
    deepseekHarnessCli
  ];

  # Hermes provides both its CLI and native desktop launcher through Home Manager.
  programs.hermes-agent = {
    enable = true;
    desktop.enable = true;
  };
}
