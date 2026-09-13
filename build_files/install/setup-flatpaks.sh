#!/usr/bin/env bash
set -euo pipefail

echo "=== Removing unwanted Flatpaks from base image and configuring user Flatpaks ==="

# Flatpaks to remove from the system scope (from Fedora/base image)
REMOVE_SYSTEM_FLATPAKS=(
  org.fedoraproject.MediaWriter
  org.fedoraproject.Platform
  org.fedoraproject.Platform.CL.default
  org.fedoraproject.Platform.GL.default
  org.fedoraproject.Platform.Locale
  org.gnome.Calculator
  org.gnome.Calendar
  org.gnome.Characters
  org.gnome.Connections
  org.gnome.Contacts
  org.gnome.Extensions
  org.gnome.Logs
  org.gnome.Loupe
  org.gnome.Maps
  org.gnome.NautilusPreviewer
  org.gnome.Papers
  org.gnome.Snapshot
  org.gnome.TextEditor
  org.gnome.Weather
  org.gnome.baobab
  org.gnome.clocks
)

# Uninstall system flatpaks if present at build time
for pkg in "${REMOVE_SYSTEM_FLATPAKS[@]}"; do
  if flatpak --system info "${pkg}" >/dev/null 2>&1; then
    echo "Removing system Flatpak: ${pkg}"
    flatpak --system uninstall --noninteractive --assumeyes "${pkg}" || true
  fi
done

# User-scope flatpaks list (empty for now; add future user flatpaks here)
USER_FLATPAKS=(
)

# Record the manifests in /etc/hyprland-image for the user flatpak setup service
install -d /etc/hyprland-image
printf '%s\n' "${REMOVE_SYSTEM_FLATPAKS[@]}" > /etc/hyprland-image/system-flatpaks-remove
printf '%s\n' "${USER_FLATPAKS[@]}" > /etc/hyprland-image/user-flatpaks

echo "Flatpak configuration manifests created in /etc/hyprland-image/"
