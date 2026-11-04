_:

{
  services.pipewire = {
    enable = true;

    alsa = {
      enable = true;
      support32Bit = true;
    };

    pulse.enable = true;
    jack.enable = false;
    wireplumber.enable = true;

    # 256 frames at 48 kHz is ~5.3 ms. Allow PipeWire to adapt between
    # 128 (~2.7 ms) and 512 (~10.7 ms) when devices or clients require it.
    extraConfig.pipewire."92-low-latency" = {
      "context.properties" = {
        "default.clock.rate" = 48000;
        "default.clock.quantum" = 256;
        "default.clock.min-quantum" = 128;
        "default.clock.max-quantum" = 512;
      };
    };
  };

  security.rtkit.enable = true;
}
