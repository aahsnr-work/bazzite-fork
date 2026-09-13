#!/usr/bin/env bash
set -euo pipefail

echo "=== Seeding a Determinate Nix store for first-boot extraction ==="

# /nix has to end up a SYMLINK into /var: composefs makes / read-only once
# deployed, but Nix needs to keep writing to its store at runtime (gc,
# profile switches, home-manager switch, self-upgrade). New top-level
# entries can only be created while the image is still building -- doing it
# from a runtime tmpfiles.d rule fails once deployed (see nix-installer #1445).
SEED_TARBALL="/usr/share/nix-store-seed.tar.zst"

rm -rf /nix
mkdir -p /nix

curl --proto '=https' --tlsv1.2 -sSf -L https://install.determinate.systems/nix |
  sh -s -- install linux \
    --init none \
    --no-confirm \
    --extra-conf "sandbox = false"

echo "Packing the seeded store into ${SEED_TARBALL}..."
tar --zstd -C / -cf "${SEED_TARBALL}" nix

rm -rf /nix
mkdir -p /var/nix
ln -s /var/nix /nix

# Unknown top-level dirs default to a restrictive SELinux context; make /nix
# resolve the same as /var so daemons/shells can traverse the symlink.
semanage fcontext -a -e /var /nix 2>/dev/null || semanage fcontext -m -e /var /nix 2>/dev/null || true
restorecon -v /nix 2>/dev/null || true

echo "Nix store seed ready; /nix -> /var/nix symlink baked into the image."
