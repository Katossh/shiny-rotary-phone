{ inputs, pkgs, ... }:

let
  deepseekHarnessDesktop = pkgs.appimageTools.wrapType2 {
    pname = "deepseek-harness-desktop";
    version = "0.2.18";
    src = pkgs.fetchurl {
      url = "https://github.com/web-casa/DeepSeek-Harness-Desktop/releases/download/v0.2.18/DSH.Desktop_0.2.18_amd64.AppImage";
      sha256 = "27404dcdb70950ac89f9b660a4cdeeabdb1545f91eb91cde72424ee4ccc2a22f";
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

    # Google Antigravity IDE from the locked Nixpkgs revision.
    pkgs.antigravity-ide

    # DSH Desktop v0.2.18 (community build) and its upstream CLI launcher.
    deepseekHarnessDesktop
    deepseekHarnessCli
  ];

  # Hermes provides both its CLI and native desktop launcher through Home Manager.
  programs.hermes-agent = {
    enable = true;
    desktop.enable = true;
  };

  # Make GitHub CLI available to every terminal and coding agent, including agy.
  programs.gh.enable = true;
}
