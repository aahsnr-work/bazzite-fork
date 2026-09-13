Looking at the Containerfile and build scripts, the current base is:

```
ghcr.io/ublue-os/silverblue-main:44
```

That's the **GNOME** flavor of the Universal Blue "main" base image family — and this project immediately fights against that choice. Look at what `build_files/global-remove` has to strip out: `gdm`, `gnome-shell`, `gnome-shell-common`, `gnome-session`, `gnome-session-wayland-session`, `gnome-settings-daemon`, `mutter`, `mutter-common`, `nautilus` (+ extensions/gsconnect/python bindings), `gnome-control-center` (+ filesystem), `gnome-online-accounts` (+ libs), `gnome-remote-desktop`, `evolution-data-server` (+ langpacks), `evolution-ews-core/langpacks`, `gnome-user-share`, `gnome-user-docs`, `xdg-desktop-portal-gnome*`, `yelp`/`yelp-libs`, and several `gnome-*-srpm-macros` packages — then `stage_install_base` masks `getty@tty2` and enables `ly` instead of `gdm`. That's a lot of machinery dedicated purely to undoing the base image's own desktop.

**There's a better fit: `ghcr.io/ublue-os/base-main`.**

Universal Blue's `main` image family explicitly ships this variant as "an empty image with no desktop," built from the same Fedora Atomic/bootc foundation as `silverblue-main` and `kinoite-main`, just without GNOME baked in. It's the same tier of image Universal Blue itself uses as the foundation for its Sway and Budgie variants — i.e., it's the intended starting point for exactly this kind of "bring your own compositor" build, not a repurposed desktop image.

Switching would let you:

- Delete the ~35-entry GNOME-specific chunk of `REMOVE_ALL` in `global-remove` (keep the non-GNOME entries like `fish`, `nano`, `vim*`, `steamdeck*`, etc. — those are unrelated to the base swap)
- Skip installing-then-removing dozens of packages, which is strictly wasted work and leaves less risk of orphaned config/cache from packages that were installed and later removed
- Shrink build time and final image size
- Reduce the chance that a future Fedora/GNOME update adds a new dependency that isn't yet in your removal list and silently reappears

Nothing else in the Containerfile is GNOME-coupled — the NVIDIA akmods stage keys off the kernel version, not the desktop; Hyprland/ly/COPR install steps are already desktop-agnostic; and the `ujust`/systemd plumbing is shared `ublue-os` infrastructure available on all the `main`-family images.

Before merging the swap, I'd verify a couple of things in a test build:

1. **Package parity** — a few things you rely on implicitly today because GNOME dragged them in (NetworkManager, polkit, PipeWire/WirePlumber, gnome-keyring — the last is already explicit in `FEDORA_PACKAGES` so you're fine there) may need to be added explicitly if `base-main` doesn't include them by default.
2. **ly on tty2** — confirm `base-main` doesn't pin a different default display manager expectation; it shouldn't, since it has no DE/DM at all, but worth a boot test.
3. Diff `rpm -qa` between a `silverblue-main`-built image and a `base-main`-built image to make sure nothing in `REMOVE_ALL` was actually load-bearing for something else.

Net: same base family, same Fedora version cadence, same update/signing model — just the flavor built for this exact use case instead of the one you're actively undoing.
