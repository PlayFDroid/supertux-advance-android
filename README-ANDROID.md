# SuperTux Advance & Brux GDK for Android

Ten projekt umożliwia zbudowanie najnowszej rozwojowej wersji gry **SuperTux Advance** (git HEAD, v0.2.57+) oraz silnika **Brux GDK** (git HEAD) jako natywnej aplikacji Android (.apk) z obsługą ekranów dotykowych (Touch Controls), automatycznym skalowaniem do rozdzielczości ekranu bez czarnych pasów, eliminacją błędów renderowania teł oraz wyrównaniem pamięci do stron 16 KB (zgodność z Androidem 15+).

---

## Wynikowy plik APK

- **Ścieżka:** `/home/fervi/STA/supertuxadvance.apk`
- **Rozmiar:** ~120 MB (zawiera pełne assety gry i biblioteki natywne)
- **Obsługiwane architektury (ABIs):** `arm64-v8a`, `x86_64`, `armeabi-v7a`
- **Wymagania:** Android 7.0+ (API 24+), target SDK 35/36 (Android 15+)
- **Orientacja:** Pełny Sensor Landscape (automatyczny obrót w poziomie 0° i 180°)
- **Podpis:** debug.keystore (v2 + v3 scheme)
- **Wyrównanie pamięci:** `16384` (16 KB page-size alignment) – spełnia rygorystyczne wymogi Google Play i Android 15+.

---

## Architektura i wprowadzone rozwiązania

### 1. Silnik Brux GDK na Androida (`brux-gdk`)
- **Wirtualny kontroler dotykowy:** Dodano zintegrowany z silnikiem wirtualny gamepad (`rte/src/brux/touch.hpp` i `touch.cpp`) renderujący przez SDL2 D-Pad oraz przyciski akcji (A/B/X/Y/Pause/Swap). Obsługuje multi-touch bez opóźnień bezpośrednio w pętli zdarzeń SDL.
- **Kompatybilność z Bionic libc:** Zabezpieczono zmienne `__stack_chk_guard` i `__stack_chk_fail` (`#ifndef __ANDROID__`), zapobiegając kolizjom symboli z systemowym Bionic libc na Androidzie.
- **Ścieżki plików w pamięci wewnętrznej:** Skonfigurowano ścieżki zapisu stanu gry (`xyGetPrefDir` -> `files/save/`) i odczytu assetów (`xyWorkDir` -> `files/game/`) wewnątrz `/data/data/org.supertuxadvance/files/`.
- **Dopasowanie do rozdzielczości ekranu (Autofit Display):**
  - Wyłączono wywoływanie `SDL_SetWindowSize` na Androidzie (które wymuszało sztywne okno 1280x720 i powodowało czarne pasy).
  - W `xyDisplayW` i `xyDisplayH` pobierane są rzeczywiste wymiary renderera SDL (`SDL_GetRendererOutputSize`), co pozwala grze dynamicznie rozszerzyć pole widzenia do pełnej szerokości każdego panoramicznego ekranu (np. 20:9, 21:9).
- **Zabezpieczenia podsystemu audio:**
  - W `rte/src/audio/audio_sdl2.cpp` dodano zabezpieczenia zakresów tablic (`bounds check`) i sprawdzanie wskaźników `NULL` w funkcjach `xyPlaySound`, `xyPlaySoundChannel` oraz `xyPlayMusic`, eliminując ryzyko błędów pamięci i wyciszania kanałów audio przy przeładowaniach poziomów.

### 2. SuperTux Advance (`supertux-advance`)
- **Automatyczne skalowanie (Auto Aspect Ratio):** Na Androidzie domyślny format ekranu ustawiany jest na `0` (Auto), dzięki czemu gra natywnie renderuje dodatkowy widok poziomy zamiast obcinać obraz lub dodawać letterbox.
- **Naprawa błędu rozmazywania tła ("hall of mirrors"):**
  - W `src/gmplay.nut` dodano czyszczenie buforów ekranu (`gvPlayScreen` i `gvPlayScreen2`) czarnym kolorem przed wyrenderowaniem tła w każdej klatce (`setDrawColor(0x000000ff); clearScreen();`).
  - W `src/bg.nut` poprawiono zapętlanie teł i operacje modulo w `dbgSunsetMountain`, `dbgDesert`, `dbgSnowPlain`, `dbgIceForest`, `dbgIceForestNight` oraz `dbgTheatre`.
- **Ekstrakcja assetów:** Assety gry pakowane są do `assets/game.zip` i przy pierwszym uruchomieniu automatycznie rozpakowywane przez `AssetExtractor.java` do katalogu aplikacji.

---

## Patche dla upstreamu (`patches/`)

Wszystkie zmiany zostały przygotowane jako czyste patche Gita, które można bezpośrednio zaaplikować do oficjalnych repozytoriów upstream:

### Patche dla `brux-gdk` (`patches/brux-gdk/`):
1. `0001-build-fix-Meson-build-PhysFS-CMP0025-SDL2_gfx-fallba.patch`: Poprawki budowania na hoście (CMake CMP0025 dla PhysFS, fallback dla SDL2_gfx, usunięcie nieużywanego libgit2).
2. `0002-android-add-Android-platform-support-internal-paths-.patch`: Obsługa Androida (Bionic stack protector, ścieżki pamięci wewnętrznej, wirtualny kontroler dotykowy, USE_CURL).
3. `0003-android-prevent-SDL_SetWindowSize-on-Android-and-imp.patch`: Wyłączenie sztywnego wymiaru okna na Androidzie i obsługa rozdzielczości z `SDL_GetRendererOutputSize`.
4. `0004-audio-add-bounds-and-null-checks-to-xyPlaySound-and-.patch`: Bezpieczne sprawdzanie indeksów i wskaźników w funkcjach odtwarzania dźwięku i muzyki.

### Patche dla `supertux-advance` (`patches/supertux-advance/`):
1. `0001-android-force-auto-aspect-ratio-to-fit-screen-automa.patch`: Wymuszenie `config.aspect = 0` na platformie Android.
2. `0002-fix-render-clear-play-screens-and-fix-background-til.patch`: Czyszczenie bufora ekranu gry przed rysowaniem tła i poprawka modulo w algorytmach teł.

---

## Jak ponownie zbudować aplikację?

Wystarczy uruchomić:
```bash
cd /home/fervi/STA
./build-android.sh
```

Dla konkretnego ABI (np. `arm64-v8a` – kompilacja trwa poniżej minuty):
```bash
./build-android.sh arm64-v8a
```
lub dla emulatora PC x86_64:
```bash
./build-android.sh x86_64
```

---

## Instalacja i uruchomienie na telefonie przez ADB

Skrypt pomocniczy automatycznie instaluje APK na pierwszym wykrytym urządzeniu ADB i restartuje grę:
```bash
./install-adb.sh
```

Ręczna instalacja:
```bash
adb install -r supertuxadvance.apk
adb shell am start -n org.supertuxadvance/.MainActivity
```

Podgląd logów gry na żywo:
```bash
adb logcat -s BRUX
```
