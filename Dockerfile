# exeslim — a small exe.dev image with Shelley and mise-managed pi.
# No preinstalled language toolchains, container engine, or browser.

FROM ubuntu:24.04@sha256:33ceb71981b602c1a7443a53469e4dba065f7503eab3078a2d7a57a2ab987517 AS base

FROM base AS pi-catalog
RUN apt-get update \
	&& apt-get install -y --no-install-recommends ca-certificates curl jq \
	&& rm -rf /var/lib/apt/lists/*
COPY vm/pi-catalog.jq /validate-catalog.jq
# A new build ID refreshes pricing without invalidating the tool installation.
ARG BUILD_ID=dev
RUN test -n "$BUILD_ID" \
	&& curl --fail --show-error --silent --location --retry 3 --max-time 60 \
		https://exe.dev/llm-gateway-models.json --output /catalog.json \
	&& jq --slurp --exit-status --from-file /validate-catalog.jq /catalog.json > /dev/null

FROM base

SHELL ["/bin/bash", "-euxo", "pipefail", "-c"]

RUN apt-get update \
	# Pull security/bugfix updates for packages already in the base layer.
	# Without this we ship whatever was current when Canonical last rebuilt
	# ubuntu:24.04, which can be months behind — and since the packages we
	# install by name are only a handful, everything else would stay stale
	# no matter how often the weekly job reruns. Same reasoning as exeuntu.
	&& DEBIAN_FRONTEND=noninteractive apt-get -y \
		-o Dpkg::Options::=--force-confold \
		-o Dpkg::Options::=--force-confdef \
		dist-upgrade \
	&& DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends \
		systemd systemd-sysv dbus dbus-user-session \
		ca-certificates curl rsync \
		# iproute2 for `ss`. ~1 MB, and it is the difference between seeing
		# and guessing when a unit is active but the proxy returns nothing —
		# 0.0.0.0:8000 (proxy can reach it) vs 127.0.0.1:8000 (it cannot).
		iproute2 \
		sudo tzdata locales ncurses-bin \
	# en_US + en_GB only; exeuntu installs locales-all, which is ~200 MB.
	# en_US.UTF-8 is the default as the least surprising for anyone else who
	# lands on the box. See the ENV LANG note below for how to override.
	&& locale-gen en_US.UTF-8 en_GB.UTF-8 \
	&& update-locale LANG=en_US.UTF-8 \
	# The base image ships policy-rc.d to stop services starting during build.
	# We run systemd at runtime, so it must go or apt-installed services will
	# silently fail to start on the VM.
	&& rm -f /usr/sbin/policy-rc.d \
	&& apt-get clean \
	&& rm -rf /var/lib/apt/lists/*

COPY vm/terminfo/ /usr/share/doc/ghostty-terminfo/
RUN tic -x -o /usr/share/terminfo /usr/share/doc/ghostty-terminfo/xterm-ghostty.terminfo \
	&& infocmp -x -A /usr/share/terminfo xterm-ghostty > /dev/null

# --- systemd, tuned for exe.dev's container-as-VM environment -----------------
# Units that hang, fail noisily, or fight the platform. Masking is safe for
# units that aren't installed, so this list can stay close to exeuntu's.
# NB: ssh.service/ssh.socket are masked because exe.dev supplies its own sshd
# from /exe.dev/bin — a distro sshd would contend for :22.
RUN systemctl mask -- \
		getty.target \
		console-getty.service \
		keyboard-setup.service \
		ssh.service \
		ssh.socket \
		systemd-resolved.service \
		systemd-remount-fs.service \
		systemd-sysusers.service \
		systemd-update-done.service \
		systemd-update-utmp.service \
		systemd-journal-catalog-update.service \
		systemd-random-seed.service \
		systemd-modules-load.service \
		modprobe@.service \
		systemd-udevd.service \
		systemd-udevd-control.socket \
		systemd-udevd-kernel.socket \
		systemd-udev-trigger.service \
		systemd-udev-settle.service \
		systemd-hwdb-update.service \
		systemd-ask-password-console.path \
		systemd-ask-password-wall.path \
		ldconfig.service \
		man-db.timer \
		dpkg-db-backup.timer \
		e2scrub_all.timer \
		apt-daily.timer \
		apt-daily-upgrade.timer \
		unattended-upgrades.service \
		iscsid.socket \
		dm-event.socket \
		ubuntu-fan.service \
		-.mount \
		etc-resolv.conf.mount \
		etc-hosts.mount \
		etc-hostname.mount \
	# systemd-logind is disabled but NOT masked — per exeuntu, it is involved
	# in populating the XDG runtime dir sockets.
	# Braces keep `|| true` bound to the disable alone, so a failed mask above
	# still aborts the build.
	&& { systemctl disable systemd-logind.service || true; } \
	&& { systemctl disable systemd-machine-id-commit.service systemd-firstboot.service systemd-sysctl.service || true; } \
	&& mkdir -p /etc/systemd/system.conf.d \
	&& printf '[Manager]\nLogLevel=info\nLogTarget=console\nSystemCallArchitectures=native\nDefaultOOMPolicy=continue\n' \
		>/etc/systemd/system.conf.d/container-overrides.conf \
	# Keep journals across reboots — `journalctl -u <svc>` is the only real
	# debugging surface on a box with no toolchain.
	&& mkdir -p /etc/systemd/journald.conf.d \
	&& printf '[Journal]\nStorage=persistent\n' \
		>/etc/systemd/journald.conf.d/persistent.conf \
	&& systemctl set-default multi-user.target

# CRITICAL: without this, systemd-growfs@-.service never runs and the root
# filesystem stays at its original size when the disk is grown — so
# `new --disk=50GB` or `resize` silently gives you an unexpanded fs.
RUN echo '/dev/vda / ext4 defaults,x-systemd.growfs 0 1' >/etc/fstab

# Stop systemd wiping /tmp at boot; it races non-systemd users that run at boot.
COPY vm/tmpfiles-tmp.conf /etc/tmpfiles.d/tmp.conf

# Makes `new --setup-script` work. Without this unit the flag is accepted and
# then silently does nothing.
COPY vm/exe-setup.service /etc/systemd/system/exe-setup.service
RUN chmod 644 /etc/systemd/system/exe-setup.service \
	&& systemctl enable exe-setup.service

# exe.dev installs the binary; these units start Shelley on demand.
COPY vm/shelley.service vm/shelley.socket /etc/systemd/system/
RUN chmod 644 /etc/systemd/system/shelley.service /etc/systemd/system/shelley.socket \
	&& systemctl enable shelley.socket

# --- exedev user -------------------------------------------------------------
# Rename the stock ubuntu user (uid 1000) rather than delete/recreate, so uid,
# gid, home and subuid/subgid ranges all line up with exeuntu.
RUN usermod -l exedev -c "exe.dev user" ubuntu \
	&& groupmod -n exedev ubuntu \
	&& mv /home/ubuntu /home/exedev \
	&& usermod -d /home/exedev exedev \
	&& usermod -aG sudo,systemd-journal exedev \
	&& sed -i 's/^ubuntu:/exedev:/' /etc/subuid /etc/subgid \
	&& printf 'exedev ALL=(ALL) NOPASSWD:ALL\nDefaults:exedev verifypw=any\n' >/etc/sudoers.d/exedev \
	&& chmod 0440 /etc/sudoers.d/exedev \
	# Linger populates /run/user/1000 so systemd --user works.
	&& mkdir -p /var/lib/systemd/linger \
	&& touch /var/lib/systemd/linger/exedev

# SSH commands need this PATH before .bashrc returns for noninteractive shells.
RUN sed -i '1i export PATH="$HOME/.local/share/mise/shims:$HOME/.local/bin:$PATH"' /home/exedev/.bashrc \
	&& printf 'export XDG_RUNTIME_DIR="/run/user/$(id -u)"\n' >>/home/exedev/.bashrc \
	&& printf 'export PATH="$HOME/.local/share/mise/shims:$HOME/.local/bin:$PATH"\nexport XDG_RUNTIME_DIR="/run/user/$(id -u)"\n' \
		>>/home/exedev/.profile \
	&& rm -rf /etc/update-motd.d/* /etc/motd \
	&& touch /home/exedev/.hushlogin \
	&& chown exedev:exedev /home/exedev/.hushlogin /home/exedev/.bashrc /home/exedev/.profile

# Share VM instructions between Shelley and pi.
COPY vm/AGENTS.md /home/exedev/.config/shelley/AGENTS.md
RUN mkdir -p /home/exedev/.pi/agent \
	&& ln -s /home/exedev/.config/shelley/AGENTS.md /home/exedev/.pi/agent/AGENTS.md \
	&& chown -R exedev:exedev /home/exedev/.config /home/exedev/.pi

# Use standalone pi; no separate Node.js or npm installation is needed.
COPY --from=ghcr.io/jdx/mise:2026.10.3@sha256:331890e7116dd3dbe6244900b75d1cb9aa4def4891181521801e4f7e9a3e50f7 /usr/local/bin/mise /usr/local/bin/mise
COPY --chown=exedev:exedev vm/mise.toml /home/exedev/.config/mise/config.toml
ENV PATH="/home/exedev/.local/share/mise/shims:/home/exedev/.local/bin:${PATH}"
USER exedev
RUN HOME=/home/exedev mise install \
	&& HOME=/home/exedev mise exec -- pi --version \
	&& HOME=/home/exedev mise exec -- fd --version \
	&& HOME=/home/exedev mise exec -- rg --version \
	&& rm -rf /home/exedev/.cache/mise /home/exedev/.local/share/mise/downloads
USER root
COPY --chown=exedev:exedev vm/pi-extension/ /home/exedev/.pi/agent/extensions/exe-dev/
COPY --from=pi-catalog --chown=exedev:exedev /catalog.json /home/exedev/.pi/agent/extensions/exe-dev/catalog.json

# exe.dev supplies its own sshd/sftp-server/sh from /exe.dev/bin, so no
# openssh-server here. Verified against a stock ubuntu:24.04 VM.
#
# The file MUST be named `init`: exe.dev's exetini decides this is an init
# from the basename and execs it rather than forking it.
COPY vm/init /usr/local/bin/init
RUN chmod +x /usr/local/bin/init

# Empty the machine ID that systemd's and dbus's package configuration baked in
# during the apt layer above. Left as-is, every VM created from this image
# shares one identity, which defeats anything that assumes machine IDs are
# unique (systemd's FixedRandomDelay=, for one). Emptied rather than removed:
# systemd reads an *absent* /etc/machine-id as first boot and presets all units,
# re-enabling the ones disabled above. Must stay after the last apt-get install,
# or a later package configure bakes in a fresh one. Mirrors exeuntu.
RUN : >/etc/machine-id \
	&& ln -sf /etc/machine-id /var/lib/dbus/machine-id

# Expose the web server ports
EXPOSE 8000 9999

# Default locale for systemd services and non-SSH contexts. Three ways to
# override, in increasing order of precedence:
#
#   1. per VM, at creation:  ssh exe.dev new --env LANG=en_GB.UTF-8 ...
#   2. on the box:           sudo update-locale LANG=en_GB.UTF-8
#   3. per SSH session:      macOS ssh_config forwards LANG via SendEnv, so an
#                            interactive login already inherits the client's.
#
# Only en_US.UTF-8 and en_GB.UTF-8 are generated (exeuntu ships locales-all at
# ~200 MB). Connecting with any other LANG gives setlocale warnings — add it to
# locale-gen above if you need one.
ENV LANG=en_US.UTF-8

LABEL "exe.dev/login-user"="exedev"
LABEL "exe.dev/install-shelley"="true"

# --- OCI metadata -------------------------------------------------------------
# Declared here, at the end, on purpose: an ARG invalidates the build cache from
# the point it is *used*, so keeping it below the apt layers means a new BUILD_ID
# does not trigger a full rebuild.
#
# `org.opencontainers.image.version` in particular must be set: ubuntu:24.04 ships
# that label as "24.04" and it is inherited, so without an override every scanner
# and `docker inspect` reports this image's version as Ubuntu's.
ARG BUILD_ID=dev
RUN printf '%s\n' "$BUILD_ID" > /etc/exeslim-build-id
LABEL org.opencontainers.image.title="exeslim" \
	org.opencontainers.image.description="Small exe.dev base image with systemd, Shelley support, mise-managed pi, and rsync." \
	org.opencontainers.image.source="https://github.com/kdheepak/exeslim" \
	org.opencontainers.image.url="https://github.com/kdheepak/exeslim" \
	org.opencontainers.image.licenses="MIT" \
	org.opencontainers.image.base.name="docker.io/library/ubuntu:24.04" \
	org.opencontainers.image.version="${BUILD_ID}"

WORKDIR /home/exedev
CMD ["/usr/local/bin/init"]
