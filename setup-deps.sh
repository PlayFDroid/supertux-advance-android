#!/usr/bin/env bash
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DEPS_DIR="$SCRIPT_DIR/deps"
mkdir -p "$DEPS_DIR"

download_and_extract() {
    local name="$1"
    local url="$2"
    local target_dir="$DEPS_DIR/$name"

    if [ -d "$target_dir" ]; then
        echo "  [OK] $name already exists."
        return 0
    fi

    echo "  [DOWNLOADING] $name from $url..."
    local archive="$DEPS_DIR/$name.tar.gz"
    if [ ! -f "$archive" ]; then
        curl --retry 5 --retry-delay 3 --retry-all-errors -fSL "$url" -o "$archive"
    fi

    echo "  [EXTRACTING] $name..."
    tar -xzf "$archive" -C "$DEPS_DIR"
    echo "  [OK] $name ready."
}

echo "=== Setting up dependencies for SuperTux Advance Android ==="
download_and_extract "SDL2-2.30.12" "https://github.com/libsdl-org/SDL/releases/download/release-2.30.12/SDL2-2.30.12.tar.gz"
download_and_extract "SDL2_image-2.8.5" "https://github.com/libsdl-org/SDL_image/releases/download/release-2.8.5/SDL2_image-2.8.5.tar.gz"
download_and_extract "SDL2_mixer-2.8.0" "https://github.com/libsdl-org/SDL_mixer/releases/download/release-2.8.0/SDL2_mixer-2.8.0.tar.gz"
download_and_extract "SDL2_net-2.2.0" "https://github.com/libsdl-org/SDL_net/releases/download/release-2.2.0/SDL2_net-2.2.0.tar.gz"

if [ -d "$SCRIPT_DIR/patches/SDL2" ]; then
    for p in "$SCRIPT_DIR"/patches/SDL2/*.patch; do
        if [ -f "$p" ]; then
            echo "  [PATCH] Applying $(basename "$p") to SDL2..."
            (cd "$DEPS_DIR/SDL2-2.30.12" && patch -p1 -N -r - < "$p" || true)
        fi
    done
fi

echo "=== All dependencies setup successfully ==="
