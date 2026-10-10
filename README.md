# exeslim

A small Ubuntu 24.04 image for [exe.dev](https://exe.dev) deployment VMs.
Build your app elsewhere, copy it to the VM, and run it with systemd.

## Create a VM

Get a build ID (`<date>.<run>.<attempt>`) from the
[package page](https://github.com/kdheepak/exeslim/pkgs/container/exeslim),
or run `mise run build-id` in this repository.

```sh
ssh exe.dev new --name=my-service \
  --image='ghcr.io/kdheepak/exeslim:<build-id>'
```

`:latest` also works, but use a build ID to avoid cached mutable tags.

## Included

- systemd with persistent logs and an `exedev` user with passwordless sudo.
- Shelley, installed by exe.dev when it creates the VM.
- mise-managed standalone pi, fd, and ripgrep. pi uses attached exe.dev LLM integrations.
- curl, rsync, TLS certificates, and `ss`.

No compiler, Python, Node.js, Go, uv, Git, Docker, nginx, or browser is
preinstalled. Use mise for extra tools or apt for system packages.

## Run and maintain

- Deploy with `scp` or `rsync`; manage services with `systemctl`.
- Bind web apps to `0.0.0.0:8000` for the default HTTPS proxy.
- Read service logs with `journalctl -u <service>`.
- Check the image build ID in `/etc/exeslim-build-id`.
- Make setup scripts safe to run again after a reboot.

Automatic package upgrades are disabled. Weekly image builds do not update
existing VMs. Recreate the VM from a new build or update packages manually:

```sh
sudo apt-get update && sudo apt-get dist-upgrade
```

Keep deployment files in your repository so you can recreate the VM.

See [Dockerfile](Dockerfile) for the image definition and
[VM instructions](vm/AGENTS.md) for agent guidance.

## License

The build recipe is [MIT licensed](LICENSE). Bundled components retain their
own licenses.
