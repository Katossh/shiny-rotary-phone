# Resource limits for local AI inference

## Locked memory (RLIMIT_MEMLOCK)

The workstation grants the configured interactive user a **2 GiB soft and hard
locked-memory limit** through `security.pam.loginLimits`.

This addresses inference warnings such as:

```text
failed to mlock ... buffer ... Cannot allocate memory
Try increasing RLIMIT_MEMLOCK
```

The PAM `memlock` value is expressed in KiB, so the configured value
`2097152` is 2 GiB. This is a ceiling for memory a process may lock with
`mlock()`; it does not reserve 2 GiB of RAM or force applications to lock it.

After applying a new NixOS generation, start a fresh login session (log out
completely and back in). Existing shells and processes keep their inherited
limits. Check the new session with:

```sh
ulimit -Sl
ulimit -Hl
```

Both should report `2097152` (KiB). To inspect an already-running inference
process, use its PID:

```sh
PID=12345 # Replace with the inference process ID
grep 'Max locked memory' "/proc/$PID/limits"
grep '^VmLck:' "/proc/$PID/status"
```

`VmLck` reports how much memory is actually locked, while the limits file
reports the process's ceiling.

### systemd services

PAM login limits do **not** apply to systemd services. If the inference server
runs as a system or user service, configure `LimitMEMLOCK=2G` on that specific
unit and verify its effective limit. Do not assume the interactive shell's
`ulimit` values are inherited by a separately managed service.
