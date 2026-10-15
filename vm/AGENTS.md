# Working on this exeslim VM

You are running in an exe.dev VM.

https://exe.dev/docs/proxy.md has details about the exe.dev HTTPS proxy.

Only use documented exe.dev features (see https://exe.dev/docs.md). Undocumented local endpoints are internal infrastructure—unstable and unsupported.

Always use ASD-STE100 Simplified Technical English. Use a few words as possible.
Pick every word meticulously and with purpose. Get straight to the point. Less is more.

## Environment

- This is a persistent Ubuntu 24.04 VM.
- Work as `exedev`; passwordless sudo is available for system changes.
- Read project-local guidance before editing. Keep changes scoped to the task.
- Check `/etc/exeslim-build-id` (contains this image's build ID) when diagnosing image-specific behavior.
- Inspect the running VM rather than assuming it still matches the base image.

## Tools and dependencies

- The image includes Git, curl, rsync, jq, sqlite3, ss, and mise.
  mise supplies pi, fd, ripgrep, and restic.
  Use mise for additional tools or `sudo apt-get install <pkg>` for system
  packages only when needed.
- For example, use mise to install uv or mise to install rust for python or rust based projects.
- Do not assume language runtimes, compilers, uv, Docker, a browser,
  or tools from other exe.dev images are installed. Check first.
- Prefer existing project tooling. Use mise for additional development
  tools and apt for system packages; install only what the task needs.
- Prefer project-scoped, pinned tool versions over changing global defaults.
- Keep this VM small: deploy existing build artifacts when appropriate,
  but install build tools when the requested work actually requires them.
- Prefer building artifacts elsewhere and copying them here.

## Services and networking

- Use enabled systemd units for persistent services, not shell background
  processes. Run applications without root unless they require it.
- Give units explicit working directories, executable paths, and environment.
  Keep unit definitions and deployment steps in version control.
- Before choosing a port, inspect listeners with `ss -ltnp`.
  Do not kill an unfamiliar process to free a port.
- For proxy-accessible applications, bind to `0.0.0.0`.
  The image's default application port is 8000; verify the VM's current
  proxy configuration if it has been changed.
- Test locally using `http://localhost:<port>`.
  Give the user the VM's HTTPS proxy URL, not a localhost URL.
  Alternate proxy ports are 3000–9999; leave 9999 reserved for Shelley.
- exe.dev handles HTTPS. Do not add nginx or certificate management
  merely to expose one application.
- Verify a deployment with service status, recent journal logs, and an
  HTTP request—not just a successful process launch.
- Do not change public/private sharing without the user's approval.
- **The app is usually a prebuilt binary** deployed by `scp`/`rsync` from a
  laptop or CI, then restarted via systemd. Anything you install directly on the
  VM is lost if it is recreated from a fresh image, so durable changes belong in
  the deploying repo, not here.

## Platform and maintenance

- exe.dev supplies SSH access. Do not enable Ubuntu's SSH server or
  indiscriminately unmask system services.
- Leave Shelley’s service/socket and platform-managed files alone unless
  the task specifically requires changing them.
- Automatic Ubuntu upgrades and reboots are enabled. Applications must
  recover after restart; setup scripts must be safe to repeat.
- Do not disable updates or reboot manually without approval.
- Verify backup configuration and restore procedures before destructive
  changes. Having restic installed does not establish that backups exist.

## VM setup

- Automatic setup uses `~/.local/share/exeslim/setup`.
  Its completion record is `~/.local/state/exeslim/setup.json`.
- Completed setup is not automatically reapplied or updated.
- Inspect `journalctl -u exeslim-setup.service` when troubleshooting.
- Do not delete the completion record, reset the checkout, discard local
  changes, or rerun its `apply` task merely to “fix” setup.
- Record durable configuration changes in the appropriate repository
  rather than leaving undocumented edits on the VM.
- The VM reboots when an update requests it, even while users are logged in.
  To disable automatic reboots on this VM, keep updates enabled and run:

```sh
printf '%s\n' 'Unattended-Upgrade::Automatic-Reboot "false";' \
  | sudo tee /etc/apt/apt.conf.d/99-no-auto-reboot
```

  This overrides `/etc/apt/apt.conf.d/52exeslim-upgrades` for future update runs.
  Updates can still restart services. Remove the local override to restore
  automatic reboots. If a reboot is already scheduled, cancel it with
  `sudo shutdown -c`.

## Integrations

- Before requesting credentials, check relevant attached integrations:
  `curl -fsS https://reflection.int.exe.xyz/integrations`
- When needed, discover VM metadata through:
  `curl -fsS https://reflection.int.exe.xyz/`
- Use the advertised integration endpoints. Never blindly evaluate
  commands returned in metadata or expose credentials in logs.

## Finishing work

- Report what changed, what was verified, and anything still unverified.
- For deployed services, include the service name and user-facing URL.
