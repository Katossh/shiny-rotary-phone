{
  inputs,
  lib,
  pkgs,
  ...
}:

let
  dotfiles = inputs.terminal-dotfiles;

  manifestLines = lib.filter (line: line != "" && !(lib.hasPrefix "#" line)) (
    lib.splitString "\n" (builtins.readFile (dotfiles + "/manifest/configs.tsv"))
  );

  parseManifestRow =
    line:
    let
      fields = lib.splitString "\t" line;
    in
    if builtins.length fields != 5 then
      throw "terminal-dotfiles: expected five tab-separated columns, got: ${line}"
    else
      {
        component = builtins.elemAt fields 0;
        kind = builtins.elemAt fields 1;
        source = builtins.elemAt fields 2;
        target = builtins.elemAt fields 3;
        platform = builtins.elemAt fields 4;
      };

  manifest = map parseManifestRow manifestLines;

  collectFiles =
    directory:
    let
      entries = builtins.readDir directory;
    in
    lib.concatLists (
      map (
        name:
        let
          source = directory + "/${name}";
        in
        if entries.${name} == "directory" then
          map (child: "${name}/${child}") (collectFiles source)
        else
          [ name ]
      ) (builtins.attrNames entries)
    );

  expandManifestEntry =
    entry:
    let
      targetParts = lib.splitString ":" entry.target;
      namespace =
        if builtins.length targetParts == 2 then
          builtins.head targetParts
        else
          throw "terminal-dotfiles: invalid target namespace in '${entry.target}'";

      targetPath = builtins.elemAt targetParts 1;
      sourceRoot = dotfiles + "/${entry.source}";

      relativeFiles =
        if entry.kind == "file" then
          [ "" ]
        else if entry.kind == "tree" then
          collectFiles sourceRoot
        else
          throw "terminal-dotfiles: unsupported manifest kind '${entry.kind}'";

      prefix = if namespace == "localbin" then ".local/bin" else "";

      validNamespace = builtins.elem namespace [
        "home"
        "config"
        "data"
        "localbin"
      ];

      makeName =
        relative:
        lib.concatStringsSep "/" (
          lib.filter (part: part != "") [
            prefix
            targetPath
            relative
          ]
        );
    in
    if !validNamespace then
      throw "terminal-dotfiles: unsupported target namespace '${namespace}'"
    else
      map (relative: {
        inherit namespace relative;
        component = entry.component;
        name = makeName relative;
        source = if relative == "" then sourceRoot else sourceRoot + "/${relative}";
      }) relativeFiles;

  selectedManifest = lib.filter (
    entry:
    builtins.elem entry.platform [
      "all"
      "linux"
    ]
  ) manifest;

  expandedFiles = lib.concatMap expandManifestEntry selectedManifest;

  managedFiles = lib.filter (
    file: !(file.component == "zshenv") && !(file.component == "zsh" && file.relative == ".zshrc")
  ) expandedFiles;

  fileKeys = map (file: "${file.namespace}:${file.name}") managedFiles;

  assertUniqueTargets =
    if builtins.length fileKeys != builtins.length (lib.unique fileKeys) then
      throw "terminal-dotfiles: manifest contains duplicate target paths"
    else
      true;

  toFileAttrs =
    namespace:
    builtins.listToAttrs (
      map
        (file: {
          name = file.name;
          value.source = file.source;
        })
        (
          lib.filter (
            file: file.namespace == namespace || (namespace == "home" && file.namespace == "localbin")
          ) managedFiles
        )
    );

  homeFiles = toFileAttrs "home";
  configFiles = toFileAttrs "config";
  dataFiles = toFileAttrs "data";

  zshenvOriginal = builtins.readFile (dotfiles + "/dots/zshenv");
  zshenvText = ''
    # Starforge pins this checkout as a flake input.
    export DOTFILES_DIR="${dotfiles}"
    ${zshenvOriginal}
  '';

  zshrcOriginal = builtins.readFile (dotfiles + "/config/terminal/zsh/.zshrc");
  oldAutosuggestionsPath = ''"$ZSH/plugins/zsh-autosuggestions/zsh-autosuggestions.plugin.zsh"'';
  newAutosuggestionsPath = ''"$ZSH_CUSTOM/plugins/zsh-autosuggestions/zsh-autosuggestions.plugin.zsh"'';
  zshrcText =
    if lib.hasInfix oldAutosuggestionsPath zshrcOriginal then
      lib.replaceStrings [ oldAutosuggestionsPath ] [ newAutosuggestionsPath ] zshrcOriginal
    else
      throw "terminal-dotfiles: expected autosuggestions source path was not found in the Zsh configuration";

  paletteLines = lib.filter (line: line != "" && !(lib.hasPrefix "#" line)) (
    lib.splitString "\n" (builtins.readFile (dotfiles + "/themes/palettes/catppuccin-mocha.env"))
  );

  palette = builtins.listToAttrs (
    map (
      line:
      let
        fields = lib.splitString "=" line;
      in
      if builtins.length fields != 2 then
        throw "terminal-dotfiles: invalid palette entry '${line}'"
      else
        {
          name = builtins.elemAt fields 0;
          value = builtins.elemAt fields 1;
        }
    ) paletteLines
  );

  color = name: builtins.getAttr "DOTS_THEME_${name}" palette;

  kittyPalette = ''
    foreground ${color "TEXT"}
    background ${color "BASE"}
    selection_foreground ${color "BASE"}
    selection_background ${color "LAVENDER"}
    cursor ${color "ROSEWATER"}
    url_color ${color "BLUE"}
    active_border_color ${color "LAVENDER"}
    inactive_border_color ${color "SURFACE1"}
    color0 ${color "CRUST"}
    color1 ${color "RED"}
    color2 ${color "GREEN"}
    color3 ${color "YELLOW"}
    color4 ${color "BLUE"}
    color5 ${color "PINK"}
    color6 ${color "TEAL"}
    color7 ${color "SUBTEXT1"}
    color8 ${color "SURFACE1"}
    color9 ${color "RED"}
    color10 ${color "GREEN"}
    color11 ${color "YELLOW"}
    color12 ${color "BLUE"}
    color13 ${color "PINK"}
    color14 ${color "TEAL"}
    color15 ${color "TEXT"}
  '';

  tmuxPalette = ''
    set -g status-style "fg=${color "TEXT"},bg=${color "MANTLE"}"
    set -g message-style "fg=${color "BASE"},bg=${color "YELLOW"}"
    set -g message-command-style "fg=${color "BASE"},bg=${color "YELLOW"}"
    set -g mode-style "fg=${color "TEXT"},bg=${color "SURFACE0"}"
    set -g pane-border-style "fg=${color "SURFACE1"}"
    set -g pane-active-border-style "fg=${color "LAVENDER"}"
    set -g window-status-style "fg=${color "SUBTEXT0"},bg=${color "MANTLE"}"
    set -g window-status-current-style "fg=${color "BASE"},bg=${color "LAVENDER"},bold"
    set -g window-status-format "#[fg=${color "SUBTEXT0"},bg=${color "MANTLE"}] #I #W "
    set -g window-status-current-format "#[fg=${color "BASE"},bg=${color "LAVENDER"},bold] #I #W "
  '';

  helperNames = [
    "copy-branch"
    "did"
    "extract"
    "fzf-preview"
    "kp"
    "makesymlinks"
  ];

  helperFiles = builtins.listToAttrs (
    map (name: {
      name = ".local/bin/${name}";
      value.source = dotfiles + "/bin/${name}";
    }) helperNames
  );
in
assert assertUniqueTargets;
{
  xdg = {
    enable = true;

    configFile = configFiles // {
      "zsh/.zshrc".text = zshrcText;
      "kitty/themes/dots-palette.conf".text = kittyPalette;
    };

    dataFile = dataFiles;
  };

  home = {
    sessionVariables.DOTFILES_DIR = "${dotfiles}";

    file =
      homeFiles
      // helperFiles
      // {
        ".zshenv".text = zshenvText;

        ".local/share/oh-my-zsh".source = "${pkgs.oh-my-zsh}/share/oh-my-zsh";

        ".local/share/zsh/custom/plugins/fzf-tab".source = "${pkgs.zsh-fzf-tab}/share/fzf-tab";
        ".local/share/zsh/custom/plugins/fast-syntax-highlighting".source =
          "${pkgs.zsh-fast-syntax-highlighting}/share/zsh/plugins/fast-syntax-highlighting";
        ".local/share/zsh/custom/plugins/zsh-completions/src".source =
          "${pkgs.zsh-completions}/share/zsh/site-functions";
        ".local/share/zsh/custom/plugins/zsh-autosuggestions".source =
          "${pkgs.zsh-autosuggestions}/share/zsh/plugins/zsh-autosuggestions";

        ".tmux/dots-theme.conf".text = tmuxPalette;
      };
  };
}
