# Resource limits for local AI inference

## Locked memory (RLIMIT_MEMLOCK)

The workstation allows the configured interactive user to lock up to **8 GiB**
per process. The limit is configured in three places because interactive PAM
sessions and the per-user systemd manager have separate lifecycles:

- **security.pam.loginLimits** sets 8 GiB soft and hard limits for
  interactive login sessions. Its memlock values are expressed in KiB, so
  the configured value is **8388608**.
- **systemd.services."user@".serviceConfig.LimitMEMLOCK** raises the
  limit of the per-user systemd manager service itself. PAM limits do not
  apply to this shared service.
- **systemd.user.settings.Manager.DefaultLimitMEMLOCK** sets the
  default soft and hard limit inherited by services launched by that
  per-user manager.

The 8 GiB limit is a ceiling, not a reserved RAM allocation. Memory successfully
locked with mlock() cannot be reclaimed through normal swapping, so keep this
limit proportional to the machine's physical memory. It is not an instruction
to lock the entire model or all available RAM.

This addresses inference warnings such as:

~~~text
failed to mlock ... buffer ... Cannot allocate memory
Try increasing RLIMIT_MEMLOCK
~~~

## Apply and verify

After applying the new NixOS generation, **reboot**. This ensures that both
the login session and the per-user systemd manager start with the new limits.
Existing shells, processes, and user managers do not acquire new limits
retroactively.

For a fresh terminal session, check the PAM limits:

~~~sh
ulimit -Sl
ulimit -Hl
~~~

Both should report **8388608** (KiB).

Check the limit assigned to the per-user systemd manager:

~~~sh
systemctl show "user@$(id -u).service" -p LimitMEMLOCK
~~~

The result should contain **LimitMEMLOCK=8589934592** (bytes). Check
the default configured for services launched by that manager:

~~~sh
grep '^DefaultLimitMEMLOCK=' /etc/systemd/user.conf
~~~

The setting should be **DefaultLimitMEMLOCK=8G:8G**.

To inspect an inference process, use its PID:

~~~sh
PID=12345 # Replace with the llama-server process ID
grep 'Max locked memory' "/proc/$PID/limits"
grep '^VmLck:' "/proc/$PID/status"
~~~

Max locked memory reports the process's soft and hard ceiling;
VmLck reports how much memory it has actually locked. For a
terminal-launched process, the PAM limit applies. For a service launched by
systemd --user, the user-manager default applies.

A system-level service is separate: if inference is later run as a system
service, configure **LimitMEMLOCK=8G:8G** on that specific unit and
verify its effective limit. Do not assume the interactive shell's limit or
the user-manager setting applies to system services.
