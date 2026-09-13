#!/usr/bin/env bash
set -euo pipefail

echo "=== Setting up Determinate Nix + home-manager ==="

# ---------------------------------------------------------------------------
# /nix must survive system updates. On an OSTree/bootc image the deployment
# root (and therefore a real /nix directory) is replaced on every upgrade, so
# /nix is pointed at the persistent /var/nix.
# ---------------------------------------------------------------------------
if [[ -e /nix && ! -L /nix ]]; then
  echo "ERROR: /nix exists as a regular directory; refusing to overwrite" >&2
  exit 1
fi
if [[ ! -e /nix ]]; then
  ln -s /var/nix /nix
fi
install -d /var/nix

# ---------------------------------------------------------------------------
# On this Fedora Atomic (ostree) base image, /usr/local is not a real
# directory -- it's a symlink to ../var/usrlocal, the standard ostree layout
# that keeps /usr read-only after deployment while leaving /usr/local
# writable (the same trick used for /home -> var/home and /opt -> var/opt,
# see install-brave.sh). /var/usrlocal itself is only created by
# systemd-tmpfiles at first boot, which never runs inside this plain
# container build, so right now the symlink exists but its target does not.
#
# Since Nov 2025 the installer unconditionally provisions Determinate Nixd
# (see https://determinate.systems/blog/installer-dropping-upstream/). Its
# `provision_determinate_nixd` action hardcodes the target to
# /usr/local/bin/determinate-nixd and does a plain
# `tokio::fs::create_dir_all("/usr/local/bin")`
# (src/action/common/provision_determinate_nixd.rs upstream). Rust's
# create_dir_all falls back to a bare `mkdir("/usr/local")` when it can't
# create the full path in one step, and mkdir() on a path that's already a
# (dangling) symlink returns EEXIST -- reproduced locally -- which is
# exactly:
#   Creating directory `/usr/local/bin`: File exists (os error 17)
#
# --force does NOT fix this, despite what a previous version of this comment
# claimed: in nix-installer's source, `force` is only consulted by the
# create_file action (e.g. writing /etc/nix/nix.conf) and the macOS volume
# planner -- never by create_directory or provision_determinate_nixd. It's
# kept below only because it's still needed for the nix.conf step.
#
# This is the same class of bug reported upstream against Fedora
# Atomic/Bluefin/Silverblue images -- the installer assumes ostree paths
# that are only provisioned at real boot time, which don't exist yet inside
# a plain container image build:
#   https://github.com/DeterminateSystems/nix-installer/issues/1682
#   https://github.com/DeterminateSystems/nix-installer/issues/1771
# (those hit it through the auto-selected `ostree` planner trying to mount
# /nix over a not-yet-real path; pinning the `linux` planner below already
# avoids that specific failure, but not this separate Determinate Nixd step).
#
# Fix: make sure the real backing directory exists before anything writes
# through the symlink, exactly like install-brave.sh does for /opt. Content
# written under /var at build time seeds the initial ostree deployment's
# /var (the same reason /var/nix is pre-created above), so determinate-nixd
# also persists correctly once the image is deployed. The -L guard keeps
# this a no-op if the base image ever ships /usr/local as a real directory
# (e.g. if ostree's opt-usrlocal-overlays becomes the default).
# ---------------------------------------------------------------------------
if [[ -L /usr/local ]]; then
  install -d "$(readlink -f /usr/local)"
else
  install -d /usr/local
fi

# ---------------------------------------------------------------------------
# Determinate Nix installer. --init none because the build container has no
# init system; the systemd units are baked via system_files and enabled in
# the services stage.
# ---------------------------------------------------------------------------
curl --proto '=https' --tlsv1.2 -sSf -L https://install.determinate.systems/nix |
  sh -s -- install linux --init none --no-confirm --force --extra-conf "sandbox = false"

# Shell integration for the baked-in profile
install -d /etc/profile.d
cat >/etc/profile.d/nix.sh <<'EOF'
# Determinate Nix (baked into the image)
export PATH="/nix/var/nix/profiles/default/bin${PATH:+:$PATH}"
EOF
chmod 644 /etc/profile.d/nix.sh

# ---------------------------------------------------------------------------
# Pre-bake home-manager into the system profile. This requires the nix daemon
# because the build container has no init system, so start determinate-nixd
# for the duration of the install. If anything fails here the build continues
# and home-manager-init.service installs it at first login instead.
# ---------------------------------------------------------------------------
NIX_BIN=/nix/var/nix/profiles/default/bin/nix
if [[ -x "${NIX_BIN}" ]]; then
  echo "Pre-installing home-manager into the system nix profile..."
  /usr/local/bin/determinate-nixd daemon >/dev/null 2>&1 &
  DAEMON_PID=$!
  sleep 3
  NIX_REMOTE=daemon timeout 1800 "${NIX_BIN}" profile install \
    --profile /nix/var/nix/profiles/default nixpkgs#home-manager ||
    echo "WARNING: could not pre-bake home-manager (will install at first login)" >&2
  kill "${DAEMON_PID}" >/dev/null 2>&1 || true
  wait "${DAEMON_PID}" >/dev/null 2>&1 || true
else
  echo "WARNING: nix binary not found; skipping the bake of home-manager" >&2
fi

echo "Determinate Nix is installed:"
"${NIX_BIN}" --version >&2 2>/dev/null || echo "nix --version unavailable" >&2
