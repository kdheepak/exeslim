# Setup integration

Attach one GitHub integration whose comment contains `exeslim-setup`.
The repository and integration names do not matter. Attaching this marker
authorizes the repository's code to run as `exedev`, which has passwordless sudo.
Only attach repositories you trust.

The repository must define an `apply` task in its root `mise.toml`:

```toml
[tasks.apply]
description = "Configure this VM"
run = "bash ./apply.sh"
```

`apply` must work without interactive input and be safe to repeat, including
after a successful run whose completion record could not be saved. It owns the
setup policy; the image does not install backup software,
choose application data, or configure credentials.

## Lifecycle

The systemd timer starts shortly after boot and checks every five minutes.
No matching integration is a successful skip. Multiple matches, invalid
metadata, network errors, and setup failures are visible service failures.
Each attempt has a 45-minute timeout. Longer setups need a
`TimeoutStartSec` override for `exeslim-setup.service`.

The helper accepts only the documented `git clone https://host/owner/repo`
form of the integration's `help` field. It extracts the URL, never executes
the help text, and clones to `~/.local/share/exeslim/setup`.

On failure, the checkout stays available for inspection. A retry uses the same
checkout and requires the original URL and a clean worktree. It does not pull,
reset, or discard local changes. The `apply` task must come from that
checkout's root `mise.toml`, not an inherited global task.

After success, the helper atomically writes
`~/.local/state/exeslim/setup.json` with the repository, initial revision, and
completion time. Later boots and timer runs leave completed setup alone.
Changing an integration does not rerun completed setup.

## Operations

```sh
systemctl status exeslim-setup.timer
journalctl -u exeslim-setup.service
sudo systemctl start exeslim-setup.service
```

For deliberate updates, inspect the checkout, update it yourself, and run
`mise -C ~/.local/share/exeslim/setup run apply`. This does not change the
initial bootstrap completion record.

To disable automatic discovery:

```sh
sudo systemctl disable --now exeslim-setup.timer
```

Git and jq are included in the image for discovery and cloning. Shelley and pi
remain the image's only agents. Setup repositories may install other software,
so their tasks must follow the policy you want for the VM.
