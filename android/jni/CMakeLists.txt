cmake_minimum_required(VERSION 3.22.1)
project(supertuxadvance C CXX)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_C_STANDARD 99)
set(CMAKE_POSITION_INDEPENDENT_CODE ON)

# 16KB page size alignment for Android 15+
add_link_options("-Wl,-z,max-page-size=16384")

set(STA_ROOT "${CMAKE_CURRENT_SOURCE_DIR}/../..")
set(DEPS_DIR "${STA_ROOT}/deps")
set(BRUX_DIR "${STA_ROOT}/brux-gdk/rte")

# ---------------------------------------------------------------------------
# SDL2
# ---------------------------------------------------------------------------
set(SDL_SHARED ON CACHE BOOL "" FORCE)
set(SDL_STATIC ON CACHE BOOL "" FORCE)
set(SDL_TEST OFF CACHE BOOL "" FORCE)
add_subdirectory("${DEPS_DIR}/SDL2-2.30.12" "${CMAKE_CURRENT_BINARY_DIR}/SDL2")

# ---------------------------------------------------------------------------
# SDL2_image (Static)
# ---------------------------------------------------------------------------
set(BUILD_SHARED_LIBS OFF CACHE BOOL "" FORCE)
set(SDL2IMAGE_SAMPLES OFF CACHE BOOL "" FORCE)
set(SDL2IMAGE_TESTS OFF CACHE BOOL "" FORCE)
set(SDL2IMAGE_BACKEND_STB ON CACHE BOOL "" FORCE)
set(SDL2IMAGE_VENDORED OFF CACHE BOOL "" FORCE)
set(SDL2IMAGE_AVIF OFF CACHE BOOL "" FORCE)
set(SDL2IMAGE_JXL OFF CACHE BOOL "" FORCE)
set(SDL2IMAGE_TIF OFF CACHE BOOL "" FORCE)
set(SDL2IMAGE_WEBP OFF CACHE BOOL "" FORCE)
add_subdirectory("${DEPS_DIR}/SDL2_image-2.8.5" "${CMAKE_CURRENT_BINARY_DIR}/SDL2_image")

# ---------------------------------------------------------------------------
# SDL2_mixer (Static)
# ---------------------------------------------------------------------------
set(SDL2MIXER_SAMPLES OFF CACHE BOOL "" FORCE)
set(SDL2MIXER_VENDORED ON CACHE BOOL "" FORCE)
set(SDL2MIXER_VORBIS_STB ON CACHE BOOL "" FORCE)
set(SDL2MIXER_FLAC_DRFLAC ON CACHE BOOL "" FORCE)
set(SDL2MIXER_MP3_MINIMP3 ON CACHE BOOL "" FORCE)
set(SDL2MIXER_WAVE ON CACHE BOOL "" FORCE)
set(SDL2MIXER_MOD OFF CACHE BOOL "" FORCE)
set(SDL2MIXER_MIDI OFF CACHE BOOL "" FORCE)
set(SDL2MIXER_OPUS OFF CACHE BOOL "" FORCE)
set(SDL2MIXER_WAVPACK OFF CACHE BOOL "" FORCE)
add_subdirectory("${DEPS_DIR}/SDL2_mixer-2.8.0" "${CMAKE_CURRENT_BINARY_DIR}/SDL2_mixer")

# ---------------------------------------------------------------------------
# SDL2_net (Static)
# ---------------------------------------------------------------------------
set(SDL2NET_SAMPLES OFF CACHE BOOL "" FORCE)
add_subdirectory("${DEPS_DIR}/SDL2_net-2.2.0" "${CMAKE_CURRENT_BINARY_DIR}/SDL2_net")

# ---------------------------------------------------------------------------
# SDL2_gfx
# ---------------------------------------------------------------------------
set(SDL2_GFX_SRCS
    "${BRUX_DIR}/subprojects/SDL2_gfx/SDL2_framerate.c"
    "${BRUX_DIR}/subprojects/SDL2_gfx/SDL2_gfxPrimitives.c"
    "${BRUX_DIR}/subprojects/SDL2_gfx/SDL2_imageFilter.c"
    "${BRUX_DIR}/subprojects/SDL2_gfx/SDL2_rotozoom.c"
)
add_library(SDL2_gfx STATIC ${SDL2_GFX_SRCS})
target_include_directories(SDL2_gfx PUBLIC
    "${BRUX_DIR}/subprojects/SDL2_gfx"
    "${DEPS_DIR}/SDL2-2.30.12/include"
)

# ---------------------------------------------------------------------------
# PhysFS
# ---------------------------------------------------------------------------
set(PHYSFS_SRCS
    "${BRUX_DIR}/subprojects/physfs/src/physfs.c"
    "${BRUX_DIR}/subprojects/physfs/src/physfs_byteorder.c"
    "${BRUX_DIR}/subprojects/physfs/src/physfs_unicode.c"
    "${BRUX_DIR}/subprojects/physfs/src/physfs_platform_posix.c"
    "${BRUX_DIR}/subprojects/physfs/src/physfs_platform_unix.c"
    "${BRUX_DIR}/subprojects/physfs/src/physfs_platform_android.c"
    "${BRUX_DIR}/subprojects/physfs/src/physfs_archiver_dir.c"
    "${BRUX_DIR}/subprojects/physfs/src/physfs_archiver_zip.c"
    "${BRUX_DIR}/subprojects/physfs/src/physfs_archiver_unpacked.c"
)
add_library(physfs STATIC ${PHYSFS_SRCS})
target_compile_definitions(physfs PRIVATE
    PHYSFS_PLATFORM_ANDROID=1
    PHYSFS_NO_CDROM_SUPPORT=1
    PHYSFS_SUPPORTS_DEFAULT=0
    PHYSFS_SUPPORTS_ZIP=1
)
target_include_directories(physfs PUBLIC
    "${BRUX_DIR}/subprojects/physfs/src"
)

# ---------------------------------------------------------------------------
# SimpleSquirrel & Squirrel
# ---------------------------------------------------------------------------
set(SSQ_BUILD_TESTS OFF CACHE BOOL "" FORCE)
set(SSQ_BUILD_EXAMPLES OFF CACHE BOOL "" FORCE)
set(SSQ_BUILD_INSTALL OFF CACHE BOOL "" FORCE)
add_subdirectory("${BRUX_DIR}/subprojects/simplesquirrel" "${CMAKE_CURRENT_BINARY_DIR}/simplesquirrel")

# ---------------------------------------------------------------------------
# libmain.so (Brux runtime engine)
# ---------------------------------------------------------------------------
set(BRUX_SRCS
    "${BRUX_DIR}/src/audio/audio.cpp"
    "${BRUX_DIR}/src/audio/audio_sdl2.cpp"
    "${BRUX_DIR}/src/brux/actors.cpp"
    "${BRUX_DIR}/src/brux/core.cpp"
    "${BRUX_DIR}/src/brux/fileio.cpp"
    "${BRUX_DIR}/src/brux/flop.cpp"
    "${BRUX_DIR}/src/brux/global.cpp"
    "${BRUX_DIR}/src/brux/graphics.cpp"
    "${BRUX_DIR}/src/brux/input.cpp"
    "${BRUX_DIR}/src/brux/main.cpp"
    "${BRUX_DIR}/src/brux/maths.cpp"
    "${BRUX_DIR}/src/brux/net.cpp"
    "${BRUX_DIR}/src/brux/shapes.cpp"
    "${BRUX_DIR}/src/brux/sprite.cpp"
    "${BRUX_DIR}/src/brux/text.cpp"
    "${BRUX_DIR}/src/brux/touch.cpp"
    "${BRUX_DIR}/src/external/cJSON.c"
)

add_library(main SHARED ${BRUX_SRCS})

target_compile_definitions(main PRIVATE
    __ANDROID__=1
)

target_include_directories(main PRIVATE
    "${CMAKE_CURRENT_SOURCE_DIR}"
    "${CMAKE_CURRENT_SOURCE_DIR}/include"
    "${BRUX_DIR}/src"
    "${DEPS_DIR}/SDL2-2.30.12/include"
    "${DEPS_DIR}/SDL2_image-2.8.5/include"
    "${DEPS_DIR}/SDL2_mixer-2.8.0/include"
    "${DEPS_DIR}/SDL2_net-2.2.0"
    "${BRUX_DIR}/subprojects/SDL2_gfx"
    "${BRUX_DIR}/subprojects/physfs/src"
    "${BRUX_DIR}/subprojects/simplesquirrel/include"
    "${BRUX_DIR}/subprojects/simplesquirrel/libs/squirrel/include"
)

target_link_libraries(main PRIVATE
    SDL2
    SDL2_image
    SDL2_mixer
    SDL2_net
    SDL2_gfx
    physfs
    simplesquirrel_static
    log
    android
)
