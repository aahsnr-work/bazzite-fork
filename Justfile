# Developer conveniences for building/linting the image locally.

set shell := ["/usr/bin/bash", "-cu"]

# Build the image locally (defaults to the pinned KERNEL_VERSION)
@build *ARGS:
    podman build --network host {{ ARGS }} .

# Shellcheck all bash scripts
@lint:
    shellcheck build_files/* build_files/install/*

# Show the Containerfile stages
@stages:
    grep -n '^FROM' Containerfile
