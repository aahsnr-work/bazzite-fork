#!/usr/bin/env bash
set -euo pipefail

echo "=== Setting up Determinate Nix + home-manager ==="

# ---------------------------------------------------------------------------
# Determinate Nix is now the installer's only output (the --determinate flag
# is implicit as of the Nov 2025 installer release; see
# https://determinate.systems/blog/installer-dropping-upstream/), and its
# `provision_determinate_nixd` step writes the daemon binary/symlinks into
# /usr/local/bin. On this ostree base image /usr/local is a symlink to the
# (nonexistent-at-build-time) ../var/usrlocal -- the same category of issue
# already worked around for /opt in install-brave.sh. mkdir() on the
# /usr/local path itself then fails with EEXIST (the symlink entry already
# "exists"), which surfaces as:
#   Creating directory `/usr/local/bin`: File exists (os error 17)
# Redirect /usr/local to a real, pre-created directory under /usr/lib, the
# same way install-brave.sh does for /opt, so the installer can create
# /usr/local/bin normally. NOTE: like /opt, this makes /usr/local part of
# the read-only /usr tree in the shipped image instead of the writable /var
# -- an accepted tradeoff already made for /opt in this image.
mkdir -p /usr/lib/usrlocal
if [[ -L /usr/local && "$(readlink /usr/local)" == "var/usrlocal" ]]; then
  rm -f /usr/local
  ln -s usr/lib/usrlocal /usr/local
fi

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
# Determinate Nix installer. --init none because the build container has no
# init system; the systemd units are baked via system_files and enabled in
# the services stage.
# ---------------------------------------------------------------------------
curl --proto '=https' --tlsv1.2 -sSf -L https://install.determinate.systems/nix |
  sh -s -- install linux --init none --no-confirm --extra-conf "sandbox = false"

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
