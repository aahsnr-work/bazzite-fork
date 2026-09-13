# bazzite-hyprland

A single custom image built on top of the plain uBlue "base" image
(`ghcr.io/ublue-os/base-main`) -- Universal Blue's desktop-free image,
built from the same Fedora Atomic/bootc foundation as `silverblue-main` and
`kinoite-main` but with no desktop environment baked in -- with the NVIDIA
open-source driver baked in through the ublue akmods pipeline. `ly` provides
the display manager; the desktop is Hyprland from the `lionheartp/Hyprland`
COPR.

Everything needed at login is baked in at build time: applications, fonts,
Flatpaks, chezmoi dotfiles and the Homebrew packages.

## What is baked in

- **Base**: `ghcr.io/ublue-os/base-main:44` (stock Fedora kernel, no desktop
  environment)
- **NVIDIA**: open driver from `ghcr.io/ublue-os/akmods-nvidia-open`
- **Display manager**: `ly` on tty2 (`getty@tty2` masked)
- **Desktop**: `hyprland-git`, `noctalia-git`, `nwg-look`, `qt6ct`,
  `xdg-desktop-portal-hyprland`, `cliphist` (lionheartp/Hyprland COPR)
- **Apps**: `zed` (Terra), VS Code, Brave, Obsidian, Zotero, Pyprland,
  TeX Live (scheme-medium + tlmgr extras), `zen-browser`
- **Fonts**: Nerd `JetBrainsMono`, `NerdFontsSymbolsOnly`; Google
  `JetBrains Mono`, `Noto Emoji`, `Noto Color Emoji`
- **Homebrew**: atuin, bat, btop, bun, cava, chafa, direnv, dust, eza, fd,
  fzf, git, gh, git-lfs, gnuplot, lazygit, pandoc, pixi, ripgrep, starship,
  tealdeer, uv, yazi, zellij
- **Dotfiles**: chezmoi (`aahsnr-configs/dots`) applied at build time
- **Flatpaks**: system and user scope managed by a bash port of BlueBuild's
  `default-flatpaks@v2` module (`system-flatpak-setup.timer` /
  `user-flatpak-setup.timer`); the baked-in Flatpak list lives in
  `build_files/install/setup-default-flatpaks.sh`. Inspect or re-run with
  `ujust flatpaks-show` / `ujust flatpaks-apply` or `hyprland-flatpak-manager`.

## ujust recipes

| Recipe                 | Purpose                                     |
| ---------------------- | ------------------------------------------- |
| `ujust update`         | topgrade-replacement maintenance step       |
| `ujust rebase`         | rebase to the latest image build            |
| `ujust doom-setup`     | set up Doom Emacs after first login         |
| `ujust flatpaks-show`  | print the Flatpaks configured by this image |
| `ujust flatpaks-apply` | manually re-run the Flatpak setup           |

## Build locally

```
podman build --network host .
```

Requires `podman` and a network connection to pull the base images.

## CI

`.github/workflows/build.yml` rebuilds the image on push to `main`, on a daily
cron, and on demand. It resolves the latest `akmods` kernel tag, verifies it
matches the base image, builds with podman, pushes to GHCR and signs with
cosign (key from `SIGNING_SECRET`).

## License

Apache-2.0. This project is a fork of the build structure of
[ublue-os/bazzite](https://github.com/ublue-os/bazzite).
