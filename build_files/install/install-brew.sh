#!/usr/bin/env bash
set -euo pipefail

echo "=== Baking Homebrew and its packages into the image ==="

BREW_PREFIX="/home/linuxbrew/.linuxbrew"
BREW_TARBALL="/usr/share/homebrew.tar.zst"

# Packages that must be baked into the image, installed with Homebrew.
BREW_PACKAGES=(
  atuin
  bat
  btop
  bun
  cava
  chafa
  direnv
  dust
  eza
  fd
  fzf
  git
  gh
  git-lfs
  gnuplot
  lazygit
  pandoc
  pixi
  ripgrep
  starship
  tealdeer
  uv
  yazi
  zellij
)

if [[ ! -f "${BREW_TARBALL}" ]]; then
  echo "ERROR: ${BREW_TARBALL} is missing; the build depends on FROM ublue-os/brew" >&2
  exit 1
fi

# 1) Unpack the Homebrew distribution into /home/linuxbrew (.linuxbrew)
mkdir -p /home/linuxbrew /tmp/homebrew
if [[ ! -x "${BREW_PREFIX}/bin/brew" ]]; then
  tar --zstd -xf "${BREW_TARBALL}" -C /tmp/homebrew
  cp -a /tmp/homebrew/home/linuxbrew/.linuxbrew /home/linuxbrew/
  rm -rf /tmp/homebrew
fi
[[ -x "${BREW_PREFIX}/bin/brew" ]] || { echo "ERROR: brew binary not found after extraction" >&2; exit 1; }
chown -R 1000:1000 /home/linuxbrew

# 2) Homebrew refuses to run as root; do the install as an unprivileged user.
#    The login user owns /home/linuxbrew (UID 1000), so the installed packages
#    are usable without any further setup.
if ! id brewbuilder &>/dev/null; then
  useradd -u 1000 -M -d /home/linuxbrew -s /usr/sbin/nologin brewbuilder
fi

runuser -u brewbuilder -- env HOME=/home/linuxbrew \
  PATH="${BREW_PREFIX}/bin:/usr/local/bin:/usr/bin:/bin" \
  HOMEBREW_PREFIX="${BREW_PREFIX}" \
  HOMEBREW_CELLAR="${BREW_PREFIX}/Cellar" \
  HOMEBREW_REPOSITORY="${BREW_PREFIX}/Homebrew" \
  HOMEBREW_NO_AUTO_UPDATE=1 \
  HOMEBREW_NO_ANALYTICS=1 \
  HOMEBREW_NO_ENV_HINTS=1 \
  HOMEBREW_NO_INSTALL_CLEANUP=1 \
  "${BREW_PREFIX}/bin/brew" install "${BREW_PACKAGES[@]}"

# 3) Mark the setup as complete so brew-setup.service is a no-op at first boot.
touch /etc/.linuxbrew

# 4) Drop the temporary build user again; the files stay owned by UID 1000 which
#    is the login user on the deployed system.
userdel brewbuilder || true

echo "Homebrew packages are baked into /home/linuxbrew:"
ls -1 "${BREW_PREFIX}/bin" | head -n 5 >&2
echo "Done."
