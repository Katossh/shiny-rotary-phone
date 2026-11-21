{ ... }:

{
  # Update only Xray-core independently of the root Nixpkgs lock. This keeps
  # unrelated workstation packages pinned while v2rayN receives the new core.
  nixpkgs.overlays = [
    (_final: prev: {
      xray = prev.callPackage ../../pkgs/xray { };
    })
  ];
}
