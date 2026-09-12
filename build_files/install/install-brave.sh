#!/usr/bin/env bash
set -euo pipefail

echo "=== Installing Brave Browser & Brave Origin ==="
# Import Brave GPG key and add the Brave repository
rpm --import https://brave-browser-rpm-release.s3.brave.com/brave-core.asc
curl -fsSLo /etc/yum.repos.d/brave-browser.repo https://brave-browser-rpm-release.s3.brave.com/brave-browser.repo

# Install brave-browser and brave-origin
dnf5 -y --setopt=install_weak_deps=False install brave-browser brave-origin

# Clean up repo file so it does not persist on the immutable system
rm -f /etc/yum.repos.d/brave-browser.repo

echo "Brave Browser and Brave Origin successfully installed."
