#!/usr/bin/env bash
set -e

# ==============================================================================
# Build Script for SuperTux Advance on Android
# Supports 16KB page-size alignment (Android 15+)
# ==============================================================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
STA_DIR="$SCRIPT_DIR/supertux-advance"
BRUX_DIR="$SCRIPT_DIR/brux-gdk"
ANDROID_DIR="$SCRIPT_DIR/android"
PROJECT_DIR="$ANDROID_DIR/project"
OUT_APK="$SCRIPT_DIR/supertuxadvance.apk"

# SDK & NDK paths
ANDROID_SDK_ROOT="${ANDROID_SDK_ROOT:-$ANDROID_HOME}"
if [ -z "$ANDROID_SDK_ROOT" ] && [ -d "$HOME/android-sdk" ]; then
    ANDROID_SDK_ROOT="$HOME/android-sdk"
fi

if [ -z "$ANDROID_SDK_ROOT" ] || [ ! -d "$ANDROID_SDK_ROOT" ]; then
    echo "ERROR: Android SDK not found. Set ANDROID_SDK_ROOT or ANDROID_HOME."
    exit 1
fi

NDK_DIR="${ANDROID_NDK_HOME:-$ANDROID_NDK_ROOT}"
if [ -z "$NDK_DIR" ]; then
    NDK_DIR=$(find "$ANDROID_SDK_ROOT/ndk" -maxdepth 1 -mindepth 1 2>/dev/null | sort -V | tail -n 1)
fi

if [ -z "$NDK_DIR" ] || [ ! -d "$NDK_DIR" ]; then
    echo "ERROR: Android NDK not found in $ANDROID_SDK_ROOT/ndk"
    exit 1
fi

BUILD_TOOLS_DIR=$(find "$ANDROID_SDK_ROOT/build-tools" -maxdepth 1 -mindepth 1 2>/dev/null | sort -V | tail -n 1)
PLATFORM_JAR=$(find "$ANDROID_SDK_ROOT/platforms" -name "android.jar" 2>/dev/null | sort -V | tail -n 1)

AAPT2="$BUILD_TOOLS_DIR/aapt2"
D8="$BUILD_TOOLS_DIR/d8"
ZIPALIGN="$BUILD_TOOLS_DIR/zipalign"
APKSIGNER="$BUILD_TOOLS_DIR/apksigner"
CMAKE_BIN="$ANDROID_SDK_ROOT/cmake/3.22.1/bin/cmake"
[ ! -x "$CMAKE_BIN" ] && CMAKE_BIN="$(which cmake)"
TOOLCHAIN_FILE="$NDK_DIR/build/cmake/android.toolchain.cmake"

echo "=== SuperTux Advance Android Build ==="
echo "SDK:         $ANDROID_SDK_ROOT"
echo "NDK:         $NDK_DIR"
echo "Build Tools: $BUILD_TOOLS_DIR"
echo "Platform:    $PLATFORM_JAR"
echo "CMake:       $CMAKE_BIN"
echo "======================================"

ABIS=("arm64-v8a" "x86_64" "armeabi-v7a")
if [ "$1" != "" ] && [ "$1" != "all" ]; then
    ABIS=("$1")
fi

# 0. Ensure dependencies and upstream sources are present
if [ ! -d "$BRUX_DIR" ]; then
    echo "Cloning brux-gdk from Codeberg..."
    git clone --recurse-submodules https://codeberg.org/KelvinShadewing/brux-gdk.git "$BRUX_DIR"
    (
        cd "$BRUX_DIR"
        git submodule update --init --recursive
        for p in "$SCRIPT_DIR"/patches/brux-gdk/*.patch; do
            [ -f "$p" ] && git apply "$p"
        done
    )
fi

if [ ! -d "$STA_DIR" ]; then
    echo "Cloning supertux-advance from Codeberg..."
    git clone https://codeberg.org/KelvinShadewing/supertux-advance.git "$STA_DIR"
    (
        cd "$STA_DIR"
        for p in "$SCRIPT_DIR"/patches/supertux-advance/*.patch; do
            [ -f "$p" ] && git apply "$p"
        done
    )
fi

"$SCRIPT_DIR/setup-deps.sh"

# 1. Package game assets from supertux-advance
echo "[1/6] Packaging game assets from supertux-advance HEAD..."
ASSETS_DIR="$PROJECT_DIR/app/src/main/assets"
mkdir -p "$ASSETS_DIR"
(
    cd "$STA_DIR"
    rm -f "$ASSETS_DIR/game.zip"

    TMP_STAGE="/tmp/sta_asset_stage"
    rm -rf "$TMP_STAGE"
    mkdir -p "$TMP_STAGE"

    cp -a game.brx res src klc icon.png lang "$TMP_STAGE/"
    rm -rf "$TMP_STAGE/res/gfx/ase"
    rm -f "$TMP_STAGE/res/gfx/unifont-merging.png"

    if command -v ffmpeg >/dev/null 2>&1; then
        python3 -c "
import os, subprocess
from concurrent.futures import ThreadPoolExecutor

mus_dir = '$TMP_STAGE/res/mus'
if os.path.isdir(mus_dir):
    files = [f for f in os.listdir(mus_dir) if f.endswith('.ogg')]
    def opt(f):
        p = os.path.join(mus_dir, f)
        if os.path.getsize(p) > 1.8 * 1024 * 1024:
            tmp = p + '.tmp.ogg'
            if subprocess.run(['ffmpeg', '-y', '-v', 'error', '-i', p, '-c:a', 'libvorbis', '-b:a', '128k', tmp]).returncode == 0:
                os.replace(tmp, p)
    with ThreadPoolExecutor(max_workers=8) as ex:
        list(ex.map(opt, files))
"
    fi

    (cd "$TMP_STAGE" && zip -9 -r -q "$ASSETS_DIR/game.zip" .)
    rm -rf "$TMP_STAGE"
)
echo "      game.zip size: $(du -h "$ASSETS_DIR/game.zip" | cut -f1)"

# 2. Build native libraries for each ABI
echo "[2/6] Compiling native libraries with 16KB page alignment..."
STRIP_BIN="$NDK_DIR/toolchains/llvm/prebuilt/linux-x86_64/bin/llvm-strip"
JNILIBS_DIR="$PROJECT_DIR/app/src/main/jniLibs"

for abi in "${ABIS[@]}"; do
    echo "  -> Building ABI: $abi..."
    BUILD_DIR="$ANDROID_DIR/build-$abi"
    mkdir -p "$BUILD_DIR"
    (
        cd "$BUILD_DIR"
        "$CMAKE_BIN" -GNinja \
            -DCMAKE_TOOLCHAIN_FILE="$TOOLCHAIN_FILE" \
            -DANDROID_ABI="$abi" \
            -DANDROID_PLATFORM=android-24 \
            -DCMAKE_BUILD_TYPE=Release \
            "$ANDROID_DIR/jni" > /dev/null
        ninja -j"$(nproc)" main > /dev/null
    )
    mkdir -p "$JNILIBS_DIR/$abi"
    cp "$BUILD_DIR/libmain.so" "$JNILIBS_DIR/$abi/"
    cp "$BUILD_DIR/SDL2/libSDL2.so" "$JNILIBS_DIR/$abi/"
    "$STRIP_BIN" "$JNILIBS_DIR/$abi/"*.so
done

# 3. Compile Android resources
echo "[3/6] Compiling Android resources with AAPT2..."
BUILD_APK_DIR="$ANDROID_DIR/build-apk"
mkdir -p "$BUILD_APK_DIR/gen" "$BUILD_APK_DIR/classes"

"$AAPT2" compile --dir "$PROJECT_DIR/app/src/main/res" -o "$BUILD_APK_DIR/compiled_res.zip" > /dev/null
"$AAPT2" link \
    -I "$PLATFORM_JAR" \
    --manifest "$PROJECT_DIR/app/src/main/AndroidManifest.xml" \
    --java "$BUILD_APK_DIR/gen" \
    -o "$BUILD_APK_DIR/base.apk" \
    "$BUILD_APK_DIR/compiled_res.zip" > /dev/null

# 4. Compile Java code and create classes.dex
echo "[4/6] Compiling Java classes and DEX..."
rm -rf "$BUILD_APK_DIR/classes"/*
javac \
    --release 17 \
    -cp "$PLATFORM_JAR" \
    -d "$BUILD_APK_DIR/classes" \
    "$BUILD_APK_DIR/gen/org/supertuxadvance/R.java" \
    "$PROJECT_DIR/app/src/main/java/org/supertuxadvance/"*.java \
    "$PROJECT_DIR/app/src/main/java/org/libsdl/app/"*.java

(
    cd "$BUILD_APK_DIR"
    "$D8" --lib "$PLATFORM_JAR" --min-api 24 --output . $(find classes -name "*.class") > /dev/null
)

# 5. Assemble APK
echo "[5/6] Assembling APK..."
(
    cd "$BUILD_APK_DIR"
    rm -f unaligned.apk
    cp base.apk unaligned.apk
    zip -u -q unaligned.apk classes.dex

    mkdir -p assets
    cp "$ASSETS_DIR/game.zip" assets/
    zip -u -0 -q unaligned.apk assets/game.zip

    mkdir -p lib
    for abi in "${ABIS[@]}"; do
        mkdir -p "lib/$abi"
        cp "$JNILIBS_DIR/$abi/"*.so "lib/$abi/"
    done
    zip -r -u -0 -q unaligned.apk lib/
)

# 6. Zipalign (16KB page alignment) & apksigner
echo "[6/6] Zipaligning (16KB) and signing APK..."
KEYSTORE="$HOME/.android/debug.keystore"
if [ ! -f "$KEYSTORE" ]; then
    mkdir -p "$HOME/.android"
    keytool -genkey -v -keystore "$KEYSTORE" -storepass android -alias androiddebugkey -keypass android -keyalg RSA -keysize 2048 -validity 10000 -dname "CN=Android Debug,O=Android,C=US"
fi

"$ZIPALIGN" -P 16 -f 4 "$BUILD_APK_DIR/unaligned.apk" "$BUILD_APK_DIR/aligned.apk"
"$ZIPALIGN" -c -P 16 4 "$BUILD_APK_DIR/aligned.apk"

"$APKSIGNER" sign \
    --ks "$KEYSTORE" \
    --ks-key-alias androiddebugkey \
    --ks-pass pass:android \
    --out "$OUT_APK" \
    "$BUILD_APK_DIR/aligned.apk"

echo ""
echo "======================================================="
echo "BUILD SUCCESSFUL!"
echo "Output APK: $OUT_APK"
echo "Size:       $(du -h "$OUT_APK" | cut -f1)"
echo "ABIs:       ${ABIS[*]}"
echo "======================================================="
