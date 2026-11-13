# exeslim

A small Ubuntu 24.04 image for [exe.dev](https://exe.dev) deployment VMs. Build your app elsewhere,
copy it to the VM, and run it with systemd.

## Create a VM

Get a build ID (`<date>.<run>.<attempt>`) from the
[package page](https://github.com/kdheepak/exeslim/pkgs/container/exeslim), or run
`mise run build-id` in this repository.

```sh
ssh exe.dev new --name=my-service \
  --image='ghcr.io/kdheepak/exeslim:<build-id>'
```

`:latest` also works, but use a build ID to avoid cached mutable tags.

## Included

- systemd with persistent logs and an `exedev` user with passwordless sudo.
- Shelley, installed by exe.dev when it creates the VM.
- mise-managed standalone pi, Codex, Claude Code, maki, chezmoi, fd, ripgrep, and restic.
- Rust with Mr. Boxington enabled for mise-managed Cargo commands.
- Git, curl, rsync, jq, sqlite3, TLS certificates, and `ss`.

pi uses attached exe.dev LLM integrations. Configure authentication separately for Codex, Claude
Code, and maki. maki's default `~/.config/maki/init.lua` loads
[maki-claude](https://github.com/bzzimmy/maki-claude), which adds a Claude Pro/Max provider.

Home configuration lives in [vm/dotfiles](vm/dotfiles), a chezmoi source directory. The build
applies it, and the image keeps it at `/usr/local/share/exeslim/dotfiles`.

No Node.js, Go, uv, Docker, nginx, or browser is preinstalled. Use mise for project tools
or apt for system packages.

## VM setup

The [init wrapper](vm/init) prepares systemd and enables low-port binding. It remounts `/proc/sys`
only when that path is a separate mount, before changing the kernel settings.

A script passed with `new --setup-script` runs at first boot as `exedev`.
[exe-setup.service](vm/exe-setup.service) loads `new --env` variables from
`/etc/profile.d/exe-env.sh`, when readable, before running `/exe.dev/setup`. It removes the script
after success or failure. Later boots skip setup unless the file is supplied again.

Inspect failures with `systemctl status exe-setup.service` and `journalctl -u exe-setup.service`.

Make scripts safe to repeat.

## Run and maintain

- Deploy with `scp` or `rsync`; manage services with `systemctl`.
- Bind web apps to `0.0.0.0:8000` for the default HTTPS proxy.
- Read service logs with `journalctl -u <service>`.
- Check the image build ID in `/etc/exeslim-build-id`.

Ubuntu package updates and required reboots are automatic, even while users are logged in. Services
must recover after a restart. See [VM instructions](vm/AGENTS.md#vm-setup) to disable automatic
reboots without disabling updates.

Image builds install the versions in [vm/mise.lock](vm/mise.lock).

New images do not update existing VMs. Use `mise upgrade` to update their mise tools, or recreate
them from a new image. Claude Code's auto-updater is disabled. Do not use `maki update`; it bypasses mise.

Keep deployment files in your repository so you can recreate the VM.

See [Dockerfile](Dockerfile) for the image definition and [VM instructions](vm/AGENTS.md) for agent
guidance.

## License

The build recipe is [MIT licensed](LICENSE). Bundled components retain their own licenses.
