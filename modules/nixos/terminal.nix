{ inputs, lib, pkgs, ... }:

let
  # Reuse terminal-dotfiles' package manifest while omitting tmux for Starforge.
  # The manifest remains shared with other platforms; this is a host-specific
  # decision rather than a change to the upstream dotfiles repository.
  packageRows =
    lib.filter
      (row: row != "" && !(lib.hasPrefix "#" row))
      (lib.splitString "\n" (builtins.readFile (inputs.terminal-dotfiles + "/manifest/packages.tsv")));

  rowsFor = manager:
    builtins.filter
      (row:
        let
          fields = lib.splitString "\t" row;
        in
        builtins.head fields == manager && builtins.elemAt fields 1 != "tmux")
      packageRows;

  resolvePackage = row:
    let
      fields = lib.splitString "\t" row;
      name = builtins.elemAt fields 1;
      class = builtins.elemAt fields 2;
      package = lib.attrByPath (lib.splitString "." name) null pkgs;
    in
    if package != null then
      package
    else if class == "optional" then
      null
    else
      throw "Required terminal package '${name}' is missing from this nixpkgs revision.";

  resolveRows = rows:
    builtins.filter (package: package != null) (map resolvePackage rows);

  packages = resolveRows (rowsFor "nixpkgs");
  fontPackages = resolveRows (rowsFor "nixpkgs-fonts");
in
{
  programs.zsh.enable = true;

  environment.systemPackages = packages ++ (with pkgs; [
    alacritty
    kitty
    vim
    xwayland-satellite
  ]);

  fonts.packages = fontPackages;
}
