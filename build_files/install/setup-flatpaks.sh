#!/usr/bin/env bash
set -euo pipefail

echo "=== Baking system Flatpaks into the image ==="

# System flatpaks from the recipe: these are the applications and runtimes
# that every user should have. Installed at build time so they are present
# right after login; a per-boot verify service tops anything up that the
# OSTree /var merge missed on a fresh deploy.
FLATPAKS=(
  com.github.Matoking.protontricks
  com.github.tchx84.Flatseal
  com.mattjakeman.ExtensionManager
  com.obsproject.Studio.Plugin.GStreamerVaapi
  com.obsproject.Studio.Plugin.Gstreamer
  com.obsproject.Studio.Plugin.OBSVkCapture
  com.ranfdev.DistroShelf
  com.vysp3r.ProtonPlus
  io.github.flattool.Warehouse
  io.missioncenter.MissionCenter
  org.freedesktop.Platform
  org.freedesktop.Platform.Compat.i386
  org.freedesktop.Platform.GL.default
  org.freedesktop.Platform.GL32.default
  org.freedesktop.Platform.VulkanLayer.MangoHud
  org.freedesktop.Platform.VulkanLayer.OBSVkCapture
  org.freedesktop.Platform.VulkanLayer.vkBasalt
  org.freedesktop.Platform.codecs-extra
  org.gnome.Calculator
  org.gnome.Calendar
  org.gnome.Characters
  org.gnome.Contacts
  org.gnome.Firmware
  org.gnome.Logs
  org.gnome.NautilusPreviewer
  org.gnome.Papers
  org.gnome.Platform
  org.gnome.Showtime
  org.gnome.TextEditor
  org.gnome.Weather
  org.gnome.baobab
  org.gnome.clocks
  org.gnome.font-viewer
  page.tesk.Refine
)

# The per-boot verifier reads this file
install -d /etc/hyprland-image
printf '%s\n' "${FLATPAKS[@]}" > /etc/hyprland-image/flatpaks

flatpak --system remote-add --if-not-exists flathub https://dl.flathub.org/repo/flathub.flatpakrepo

# Baked in; tolerate individual failures (the flatpak-setup service retries
# anything that failed here on the next boot).
for pkg in "${FLATPAKS[@]}"; do
  echo "Installing Flatpak: ${pkg}"
  flatpak --system install --noninteractive --assumeyes flathub "${pkg}" \
    || echo "WARNING: could not install ${pkg} at build time (will retry at boot)" >&2
done

echo "System Flatpaks are baked into the image."
