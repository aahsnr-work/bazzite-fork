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
# Determinate Nix installer. --init none because the build container has no
# init system; the systemd units are baked via system_files and enabled in
# the services stage.
#
# --force is required on this base image: ghcr.io/ublue-os/silverblue-main
# is a full Fedora Atomic desktop image, so the standard Fedora `filesystem`
# package has already pre-created /usr/local/{bin,etc,lib,...} as real
# directories (unlike the slim/minimal images -- Ubuntu containers, GitHub
# Actions runners, etc. -- that the installer is usually tested against).
# Since Nov 2025 the installer unconditionally provisions Determinate Nixd
# (see https://determinate.systems/blog/installer-dropping-upstream/), whose
# `provision_determinate_nixd` step needs to (re)create /usr/local/bin to
# drop its daemon binary/symlinks into. By default the installer refuses to
# touch a path it finds already existing there, which is exactly what
# produces:
#   Creating directory `/usr/local/bin`: File exists (os error 17)
# --force tells it to go ahead and recreate any such pre-existing paths,
# which is safe here since this is a from-scratch image build.
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
