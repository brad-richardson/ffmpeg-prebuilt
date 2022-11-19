#!/usr/bin/env bash

set -eux

: ${TARGET?}

case $TARGET in
    x86_64-*)
        ARCH="x86_64"
        ;;
    arm64-*)
        ARCH="arm64"
        ;;
    *)
        echo "Unknown target: $TARGET"
        exit 1
        ;;
esac

mkdir -p ~/ffmpeg_sources ~/bin

# libx264
cd ~/ffmpeg_sources && \
git -C x264 pull 2> /dev/null || git clone --depth 1 https://code.videolan.org/videolan/x264.git && \
cd x264 && \
PATH="$HOME/bin:$PATH" PKG_CONFIG_PATH="$HOME/ffmpeg_build/lib/pkgconfig" ./configure --prefix="$HOME/ffmpeg_build" --bindir="$HOME/bin" --enable-static --enable-pic && \
PATH="$HOME/bin:$PATH" make -j$(nproc) && \
make install

# libx265
cd ~/ffmpeg_sources && \
wget -O x265.tar.bz2 https://bitbucket.org/multicoreware/x265_git/get/master.tar.bz2 && \
tar xjvf x265.tar.bz2 && \
cd multicoreware*/build/linux && \
PATH="$HOME/bin:$PATH" cmake -G "Unix Makefiles" -DCMAKE_INSTALL_PREFIX="$HOME/ffmpeg_build" -DENABLE_SHARED=off ../../source && \
PATH="$HOME/bin:$PATH" make -j$(nproc) && \
make install

FFMPEG_CONFIGURE_FLAGS=(
    --cc=/usr/bin/clang
    --prefix="$HOME/ffmpeg_build"
    --enable-cross-compile
    --target-os=darwin
    --arch=$ARCH
    --extra-ldflags="-target $TARGET"
    --extra-cflags="-target $TARGET"
    --enable-runtime-cpudetect
    --pkg-config-flags="--static"
    --extra-cflags="-I$HOME/ffmpeg_build/include" \
    --extra-ldflags="-L$HOME/ffmpeg_build/lib" \
    --extra-libs="-lpthread -lm" \
    --ld="g++" \
    --bindir="$HOME/bin" \
    --disable-autodetect \
    --enable-gpl \
    --enable-bzlib \
    --enable-cuvid \
    --enable-lzma \
    --enable-zlib \
    --enable-libopus \
    --enable-libx264 \
    --enable-libx265 \
    --disable-debug
)

cd ~/ffmpeg_sources && \
wget -O ffmpeg-snapshot.tar.bz2 https://ffmpeg.org/releases/ffmpeg-snapshot.tar.bz2 && \
tar xjvf ffmpeg-snapshot.tar.bz2 && \
cd ffmpeg && \
PATH="$HOME/bin:$PATH" PKG_CONFIG_PATH="$HOME/ffmpeg_build/lib/pkgconfig" \
./configure "${FFMPEG_CONFIGURE_FLAGS[@]}" || (cat ffbuild/config.log && exit 1)

perl -pi -e 's{HAVE_MACH_MACH_TIME_H 1}{HAVE_MACH_MACH_TIME_H 0}' config.h

PATH="$HOME/bin:$PATH" make V=1 && \
make install

chown -R $(stat -f '%u:%g' $HOME) "$HOME/ffmpeg_build"
