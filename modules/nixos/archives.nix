{ pkgs, ... }:

{
  # A unified CLI for inspecting, compressing, and extracting archives.
  environment.systemPackages = [ pkgs.ouch ];
}
