You are running in an exe.dev VM.

https://exe.dev/docs/proxy.md has details about the exe.dev HTTPS proxy.

Only use documented exe.dev features (see https://exe.dev/docs.md). Undocumented local endpoints are internal infrastructure—unstable and unsupported.

## This VM runs exeslim, not exeuntu

This deployment image includes systemd, TLS roots, curl, rsync, Git, jq, and mise.
Mise installs standalone pi, fd, and ripgrep. exe.dev installs Shelley when
it creates the VM.
Do not assume the full exeuntu toolbox is present.

**Image build:** `/etc/exeslim-build-id` contains this image's build ID.

**pi:** Run `pi`. The bundled extension uses attached exe.dev LLM integrations.
Mise shims are on PATH. Its VM config is `~/.config/mise/config.toml`.

**Not installed:** compiler/`build-essential`, Node.js, Go, uv,
Docker, nginx, or Chrome. No Claude, Codex, or OpenCode agent is installed.
Use mise for additional tools or `sudo apt-get install <pkg>` for system
packages only when needed. Prefer building artifacts elsewhere and copying
them here.

**Setup:** One attached GitHub integration whose comment contains `exeslim-setup`
opts into running that repository's `mise run apply`. Setup retries until
completion is recorded, then does not pull updates or reapply on reboot.
Read its logs with `journalctl -u exeslim-setup`.
The checkout is `~/.local/share/exeslim/setup`;
the completion record is `~/.local/state/exeslim/setup.json`.

**Services are systemd units.** Start/stop with `systemctl`. Read logs with
`journalctl -u <name>` without sudo. Journals persist across reboots.

**Ubuntu updates run daily.** Security and stable-release updates are enabled;
proposed updates and backports are not. Python and Perl support the system
update tools. These updates do not update mise-managed tools or Shelley.
Read update logs with `journalctl -u apt-daily-upgrade.service`.

The VM reboots when an update requests it, even while users are logged in.
To disable automatic reboots on this VM, keep updates enabled and run:

```sh
printf '%s\n' 'Unattended-Upgrade::Automatic-Reboot "false";' \
  | sudo tee /etc/apt/apt.conf.d/99-no-auto-reboot
```

This overrides `/etc/apt/apt.conf.d/52exeslim-upgrades` for future update runs.
Updates can still restart services. Remove the local override to restore
automatic reboots. If a reboot is already scheduled, cancel it with
`sudo shutdown -c`.

**The app is normally a prebuilt binary** deployed by `scp`/`rsync` from a
laptop or CI, then restarted via systemd. Anything you install directly on the
VM is lost if it is recreated from a fresh image, so durable changes belong in
the deploying repo, not here.
