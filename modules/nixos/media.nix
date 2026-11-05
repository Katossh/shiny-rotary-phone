{ pkgs, ... }:

{
  # Media playback and downloading are user-facing media tools, not part of
  # the compiler/debugger/toolchain module.
  environment.systemPackages = with pkgs; [
    mpv
    yt-dlp
  ];
}
