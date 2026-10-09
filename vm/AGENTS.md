You are running in an exe.dev VM.

https://exe.dev/docs/proxy.md has details about the exe.dev HTTPS proxy.

Only use documented exe.dev features (see https://exe.dev/docs.md). Undocumented local endpoints are internal infrastructure—unstable and unsupported.

## This VM runs exeslim, not exeuntu

This deployment image includes systemd, TLS roots, curl, rsync, and mise.
Mise installs standalone pi, fd, and ripgrep. exe.dev installs Shelley when
it creates the VM.
Do not assume the full exeuntu toolbox is present.

**Image build:** `/etc/exeslim-build-id` contains this image's build ID.

**pi:** Run `pi`. The bundled extension uses attached exe.dev LLM integrations.
Mise shims are on PATH. Its VM config is `~/.config/mise/config.toml`.

**Not installed:** compiler/`build-essential`, Python, Node.js, Go, uv, git,
Docker, nginx, or Chrome. No Claude, Codex, or OpenCode agent is installed.
Use mise for additional tools or `sudo apt-get install <pkg>` for system
packages only when needed. Prefer building artifacts elsewhere and copying
them here.

**Services are systemd units.** Start/stop with `systemctl`. Read logs with
`journalctl -u <name>` without sudo. Journals persist across reboots.

**The app is normally a prebuilt binary** deployed by `scp`/`rsync` from a
laptop or CI, then restarted via systemd. Anything you install directly on the
VM is lost if it is recreated from a fresh image, so durable changes belong in
the deploying repo, not here.
