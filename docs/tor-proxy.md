# Persistent Tor SOCKS5 proxy

The workstation profile runs the NixOS Tor daemon as a system service. It
starts automatically at boot and exposes a local SOCKS5 proxy at
`127.0.0.1:9050`; opening Tor Browser is not required.

The client is configured to use **WebTunnel bridges only**. It does not route
ordinary system traffic through Tor, change the AmneziaVPN/Xray routing
configuration, or open a listening port on the LAN. Applications must opt in
to using the SOCKS5 proxy.

## Add your WebTunnel bridges

Bridge addresses and WebTunnel URLs are deliberately not committed to this
repository and are not embedded in the Nix store. The system creates an empty
`/etc/tor/bridges.conf` file on first activation. It is owned by root, readable
by the `tor` group, and survives system rebuilds.

1. Obtain WebTunnel bridge lines from the
   [Tor Project bridge distributor](https://bridges.torproject.org/options/).
   Select **webtunnel**. The distributor may require access to the site through
   another connection or a different delivery method.
2. Open the local file:

   ```sh
   sudoedit /etc/tor/bridges.conf
   ```

3. Add one Tor configuration directive per bridge. The bridge distributor
   normally returns the bridge parameters beginning with `webtunnel`; prefix
   each one with `Bridge `. Keep every parameter exactly as supplied:

   ```text
   Bridge webtunnel <IP>:<PORT> <FINGERPRINT> url=<URL> ver=<VERSION>
   ```

   If a source already gives you a complete line beginning with `Bridge `,
   paste it without adding a second prefix. You can add multiple bridges, one
   per line.
4. Restart Tor so it rereads the file:

   ```sh
   sudo systemctl restart tor.service
   ```

Do not publish your bridge lines in this repository, issues, or public logs.
Replacing a bridge is simply a matter of editing this file and restarting the
service. If the file is empty, Tor still runs locally but cannot bootstrap
through a bridge.

## Verify the proxy

Check the service and its recent log messages:

```sh
systemctl status tor.service
journalctl -u tor.service -b --no-pager -n 80
```

Check that the SOCKS listener is bound to loopback:

```sh
ss -lnt 'sport = :9050'
```

Test Tor while keeping DNS resolution inside the proxy:

```sh
curl --socks5-hostname 127.0.0.1:9050 https://check.torproject.org/api/ip
```

A successful response reports `"IsTor": true`. If the service is active but
the request does not complete, inspect the Tor journal and confirm that at
least one bridge line is present and still reachable. Bridges can be blocked
or go offline; obtain replacement lines from the Tor Project when necessary.

## Use it from applications

Configure an application's SOCKS5 proxy as:

- Host: `127.0.0.1`
- Port: `9050`
- Protocol: SOCKS5

For command-line tools, use a SOCKS5 mode that resolves hostnames through the
proxy (for example, curl's `--socks5-hostname` or a `socks5h://` URL). This
avoids sending destination DNS lookups outside the proxy.

The proxy is local to this machine. Do not change the listener to
`0.0.0.0` or a LAN address unless you deliberately intend to expose an
unauthenticated SOCKS proxy to other devices.

## Apply the NixOS change

After pulling the repository update, validate and activate the configuration
using the normal workstation workflow:

```sh
nixcfg check
nixcfg switch
```

The first activation creates the empty bridge file and enables the Tor service.
Add bridge lines as described above, then restart `tor.service`. The repository
change does not activate itself on the workstation.
