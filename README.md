# SuperTux Advance for Android

Port of **SuperTux Advance** (git HEAD, v0.2.57+) and the **Brux GDK** engine for modern Android devices.

Features native performance, built-in multi-touch controls, automatic aspect ratio adaptation without letterboxing, 16 KB page-size ELF alignment for Android 15+, and fixes for rendering and audio glitches.

---

## Features

- **Up-to-date Sources:** Built against the latest development branches (`main`/HEAD) of SuperTux Advance and Brux GDK.
- **Android 15+ Ready:** 16 KB page-size ELF alignment (`-Wl,-z,max-page-size=16384` and `zipalign -P 16 4`).
- **Low-Latency Virtual Touch Controls:** Responsive 8-way D-pad, action buttons (A/B/X/Y), and Pause/Swap buttons rendered directly through SDL2 without Java overlay latency.
- **Dynamic Display Autofit:** Automatically adapts to modern panoramic screens (19:9, 20:9, 21:9) using native renderer output sizing (`config.aspect = 0`).
- **Render & Background Glitch Fixes:** Eliminates background smearing ("hall of mirrors" ghosting) by clearing draw buffers and fixing parallax tiling/modulo arithmetic.
- **Audio Subsystem Hardening:** Bounds checking and NULL-pointer safety guards in SDL_mixer wrapper preventing sound dropouts and audio channel corruption.
- **Fully Self-Contained:** Automatically fetches dependencies and builds directly via `./build-android.sh`.

---

## Pre-built APK

The signed, 16 KB aligned APK is available in the repository releases or can be built locally.
- **Target SDK:** 35/36 (Android 15+)
- **Minimum SDK:** 24 (Android 7.0+)
- **Architecture (ABIs):** `arm64-v8a`, `x86_64`, `armeabi-v7a`
- **Orientation:** Full Sensor Landscape

---

## Building from Source

### Prerequisites
- Android SDK (API 35/36 platform)
- Android NDK (r25+ or r28+)
- CMake & Ninja
- Java JDK 17+
- `curl`, `tar`, `zip`, `git`

Set your environment variables (or rely on default `~/android-sdk`):
```bash
export ANDROID_SDK_ROOT="$HOME/android-sdk"
export ANDROID_NDK_HOME="$ANDROID_SDK_ROOT/ndk/<version>"
```

### Build Commands
Clone the repository:
```bash
git clone https://github.com/PlayFDroid/supertux-advance-android.git
cd supertux-advance-android
```

Build for all ABIs (`arm64-v8a`, `x86_64`, `armeabi-v7a`):
```bash
./build-android.sh
```

Or build for a specific ABI (e.g. `arm64-v8a` for physical devices, or `x86_64` for emulators):
```bash
./build-android.sh arm64-v8a
```

The script will automatically:
1. Download required SDL2 dependencies (`SDL2`, `SDL2_image`, `SDL2_mixer`, `SDL2_net`).
2. Clone upstream `brux-gdk` and `supertux-advance` from Codeberg if not present.
3. Apply Git patches from `patches/`.
4. Package game assets into `assets/game.zip`.
5. Compile native libraries with 16 KB alignment.
6. Assemble, zipalign (`-P 16`), and sign the final APK (`supertuxadvance.apk`).

---

## Installation via ADB

To install and launch on a connected device:
```bash
./install-adb.sh
```
Or manually:
```bash
adb install -r supertuxadvance.apk
adb shell am start -n org.supertuxadvance/.MainActivity
```

Monitor live game logs:
```bash
adb logcat -s BRUX
```

---

## Patches for Upstream

All engine and game improvements are maintained as clean Git patch series in `patches/`:

### `patches/brux-gdk/`
- `0001-build-fix-Meson-build-PhysFS-CMP0025-SDL2_gfx-fallba.patch`: Host build fixes (CMake CMP0025 for PhysFS, SDL2_gfx fallback, remove unused libgit2).
- `0002-android-add-Android-platform-support-internal-paths-.patch`: Android support (Bionic stack protector guards, internal storage paths, on-screen touch gamepad, USE_CURL guards).
- `0003-android-prevent-SDL_SetWindowSize-on-Android-and-imp.patch`: Window size handling fix on Android using `SDL_GetRendererOutputSize`.
- `0004-audio-add-bounds-and-null-checks-to-xyPlaySound-and-.patch`: Array bounds checking and NULL validation in SDL_mixer playback functions.

### `patches/supertux-advance/`
- `0001-android-force-auto-aspect-ratio-to-fit-screen-automa.patch`: Automatic aspect ratio detection on Android (`config.aspect = 0`).
- `0002-fix-render-clear-play-screens-and-fix-background-til.patch`: Play screen buffer clearing before drawing backgrounds and parallax modulo fixes.

---

## Technical Report & Bug Investigation

### 1. 16 KB ELF Alignment & Android 15 Bionic Compatibility
Starting with Android 15, native libraries must align `LOAD` segments to 16 KB boundaries to support 16 KB page-size devices.
Native builds are linked with:
```cmake
add_link_options("-Wl,-z,max-page-size=16384")
```
and aligned using `zipalign -P 16 4`. In addition, custom definitions of `__stack_chk_guard` and `__stack_chk_fail` in Brux were guarded to avoid symbol collisions with Android's Bionic libc.

### 2. Low-Latency Embedded Touch Controls
Instead of using Android UI overlays, virtual touch controls are implemented inside Brux's SDL event processing loop (`rte/src/brux/touch.cpp`). Directional inputs (D-pad) and action buttons (A/B/X/Y/Pause/Swap) track multi-touch pointer IDs directly from `SDL_FINGERDOWN`, `SDL_FINGERMOTION`, and `SDL_FINGERUP`, delivering zero-latency input without ghost releases.

### 3. Display Autofit & Aspect Ratio Scaling
On wide modern displays (e.g. 20:9), calling `SDL_SetWindowSize()` on Android breaks native surface sizing, leading to heavy letterboxing or distorted aspect ratios. By removing `SDL_SetWindowSize()` calls on Android and deriving metrics from `SDL_GetRendererOutputSize()`, the game naturally expands its field of view horizontally to match the hardware display.

### 4. Background Smearing ("Hall of Mirrors")
Certain level backgrounds smeared across the screen during player movement. The issue had two causes:
1. `src/gmplay.nut` drew the background pass onto `gvPlayScreen` without clearing the canvas first, preserving unpainted pixel trails from previous frames.
2. In `src/bg.nut`, parallax scrolling routines performed raw modulo operations (`% screenW`) on negative floating-point coordinates, causing texture wrapping gaps.
Buffer clearing (`setDrawColor(0x000000ff); clearScreen();`) and corrected tiling loops eliminated the glitch completely.

### 5. Menu Arrow Artifacts
Menu selection arrows were drawn via `drawSprite(size.f, 16, ...)` in `src/menus.nut`, where `size.f` was set to font ID `font2`. Although frame 16 of `res/gfx/font2.png` contains an arrow icon, `drawSprite()` operates on the global sprite array `vcSprites`, not `vcFonts`. Under dynamic reload or resource index shifts, slot 2 referenced player animation frames instead, causing character sprites to appear in place of cursor arrows.

### 6. Audio Subsystem Hardening
Sound effects intermittently stopped playing when levels reset or when sound vectors were modified. `audio_sdl2.cpp` lacked bounds checks before calling `Mix_PlayChannel()` and `Mix_PlayMusic()`. Adding bounds and NULL checks in `xyPlaySound()`, `xyPlaySoundChannel()`, and `xyPlayMusic()` prevents SDL_mixer channel lockups.

---

## License

- **SuperTux Advance:** GPLv3 (Kelvin Shadewing & contributors)
- **Brux GDK:** AGPLv3 (Kelvin Shadewing & contributors)
- **Android Port & Packaging:** GPLv3 / zlib (PlayFDroid & contributors)
