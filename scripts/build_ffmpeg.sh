#!/bin/bash
set -euo pipefail

# Root dir is where the script is launched from (iptvffmpeg/)
ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
FFMPEG_SRC="$ROOT_DIR/FFmpeg"
BUILD_DIR="$FFMPEG_SRC/build"
NPROC=$(sysctl -n hw.ncpu)

echo "Building FFmpeg from source at: $FFMPEG_SRC"
echo "Build output will go to: $BUILD_DIR"
echo "Detected $NPROC cores"

build_target() {
    PLATFORM=$1
    ARCH=$2
    TARGET_OS=$3
    MIN_VERSION=$4
    SDK_PATH=$5

    OUT_DIR="$BUILD_DIR/$PLATFORM/$ARCH"
    mkdir -p "$OUT_DIR"
    cd "$FFMPEG_SRC"

    echo "Configuring FFmpeg for $PLATFORM ($ARCH)..."

    if [[ "$PLATFORM" == "ios" || "$PLATFORM" == "tvos" ]]; then
        if [[ "$PLATFORM" == "ios" ]]; then
            SDK_NAME=iphoneos
        else
            SDK_NAME=appletvos
        fi

        EXTRA_LDFLAGS="-m$PLATFORM-version-min=$MIN_VERSION"

        ./configure \
	    --disable-programs \
	    --disable-doc \
	    --enable-network \
	    --enable-shared \
	    --disable-static \
	    --sysroot="$(xcrun --sdk $SDK_NAME --show-sdk-path)" \
	    --enable-cross-compile \
            --arch=$ARCH \
            --prefix="$OUT_DIR" \
            --cc="xcrun --sdk $SDK_NAME clang -arch $ARCH" \
	    --cxx="xcrun --sdk $SDK_NAME clang++ -arch $ARCH" \
            --extra-ldflags="$EXTRA_LDFLAGS" \
	    --install-name-dir='@rpath' \
	    --disable-audiotoolbox

    else
# ../configure --prefix=/usr/local/ffmpeg/arm64 --disable-doc --enable-network \
#    --enable-shared --enable-cross-compile --arch=arm64 --cc="clang -arch arm64"
        # Native macOS build
        EXTRA_LDFLAGS="-mmacosx-version-min=$MIN_VERSION"

        ./configure \
            --prefix="$OUT_DIR" \
	    --disable-doc \
	    --enable-network \
	    --enable-shared \
	    --disable-static \
	    --enable-cross-compile \
	    --arch=$ARCH \
	    --cc="clang -arch $ARCH" \
            --extra-ldflags="$EXTRA_LDFLAGS"
    fi

    make clean
    make -j"$NPROC"
    make install
}

# macOS x86_64
build_target macos x86_64 darwin 12.0 ""

# macOS arm64
build_target macos arm64 darwin 12.0 ""

# iOS arm64
IOS_SDK=$(xcrun --sdk iphoneos --show-sdk-path)
build_target ios arm64 darwin 15.0 "$IOS_SDK"

# tvOS arm64
TVOS_SDK=$(xcrun --sdk appletvos --show-sdk-path)
build_target tvos arm64 darwin 15.0 "$TVOS_SDK"

echo "FFmpeg build completed successfully."

