#!/bin/bash

# Root dir is where the script is launched from (iptvffmpeg/)
ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
FFMPEG_SRC="$ROOT_DIR/FFmpeg"
BUILD_DIR="$FFMPEG_SRC/build"
NPROC=$(sysctl -n hw.ncpu)

echo "Building FFmpeg from source at: $FFMPEG_SRC"
echo "Build output will go to: $BUILD_DIR"
echo "Detected $NPROC cores"

# Creates an Info.plist file for a given framework:
build_info_plist() {
    local file_path="$1"
    local framework_name="$2"
    local framework_id="$3"
    local platform="$4"
    local min_version="$5"

    # Determine platform-specific settings
    local supported_platforms
    local minimum_version_key="MinimumOSVersion"
    
    case "$platform" in
        "ios")
            supported_platforms="iPhoneOS"
            ;;
        "tvos")
            supported_platforms="AppleTVOS"
            ;;
        "macos")
            supported_platforms="MacOSX"
            minimum_version_key="LSMinimumSystemVersion"
            ;;
        *)
            supported_platforms="MacOSX"
            minimum_version_key="LSMinimumSystemVersion"
            ;;
    esac

    info_plist="<?xml version=\"1.0\" encoding=\"UTF-8\"?>
<!DOCTYPE plist PUBLIC \"-//Apple//DTD PLIST 1.0//EN\" \"http://www.apple.com/DTDs/PropertyList-1.0.dtd\">
<plist version=\"1.0\">
<dict>
    <key>CFBundleDevelopmentRegion</key>
    <string>en</string>
    <key>CFBundleExecutable</key>
    <string>${framework_name}</string>
    <key>CFBundleIdentifier</key>
    <string>${framework_id}</string>
    <key>CFBundleInfoDictionaryVersion</key>
    <string>6.0</string>
    <key>CFBundleName</key>
    <string>${framework_name}</string>
    <key>CFBundlePackageType</key>
    <string>FMWK</string>
    <key>CFBundleShortVersionString</key>
    <string>7.0.2</string>
    <key>CFBundleVersion</key>
    <string>7.0.2</string>
    <key>CFBundleSignature</key>
    <string>????</string>
    <key>${minimum_version_key}</key>
    <string>${min_version}</string>
    <key>CFBundleSupportedPlatforms</key>
    <array>
        <string>${supported_platforms}</string>
    </array>
    <key>NSPrincipalClass</key>
    <string></string>
</dict>
</plist>"
    echo "$info_plist" > "${file_path}"
}

# Creates framework from a dylib file:
create_framework() {
    local platform="$1"
    local arch="$2"
    local framework_name="$3"
    local min_version="$4"
    
    local build_path="$BUILD_DIR/$platform/$arch"
    local framework_complete_path="${build_path}/framework/${framework_name}.framework/${framework_name}"
    local dylib_regex="^@rpath/.*\.dylib$"

    echo "Creating framework for $framework_name ($platform/$arch)"

    # Create framework directory and copy dylib file and headers to this directory:
    mkdir -p ${build_path}/framework/${framework_name}.framework
    mkdir -p ${build_path}/framework/${framework_name}.framework/Headers
    cp ${build_path}/lib/${framework_name}.dylib ${framework_complete_path}
    cp -r ${build_path}/include/${framework_name}/* ${build_path}/framework/${framework_name}.framework/Headers

    # Change the shared library identification name
    install_name_tool -id @rpath/${framework_name}.framework/${framework_name} "${framework_complete_path}"

    # Add Info.plist file into the framework directory:
    build_info_plist "${build_path}/framework/${framework_name}.framework/Info.plist" \
        "${framework_name}" "io.qt.ffmpegkit.${framework_name}" "$platform" "$min_version"

    # Process dependencies
    otool -L "$framework_complete_path" | awk '/\t/ {print $1}' | grep -E "$dylib_regex" | while read -r dependency_path; do
        found_name=$(tmp=${dependency_path/*\/}; echo ${tmp/\.*})
        if [ "$found_name" != "$framework_name" ]; then
            echo "Processing: $found_name from $dependency_path in $framework_name"
            install_name_tool -change "$dependency_path" @rpath/${found_name}.framework/${found_name} "${framework_complete_path}"
        fi
    done
    
    echo "Framework $framework_name for $platform/$arch created"
}

# Creates frameworks for all FFmpeg libraries for a specific platform/arch
create_frameworks() {
    local platform="$1"
    local arch="$2"
    local min_version="$3"
    
    local ffmpeg_libs="libavcodec libavformat libavutil libswresample libswscale"
    
    for name in $ffmpeg_libs; do
        create_framework "$platform" "$arch" "$name" "$min_version"
    done
}

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
        EXTRA_CFLAGS="-m$PLATFORM-version-min=$MIN_VERSION"

        ./configure \
	    --disable-programs \
        --disable-xlib \
        --disable-lzma \
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
        --extra-cflags="$EXTRA_CFLAGS" \
        --extra-ldflags="$EXTRA_LDFLAGS" \
	    --install-name-dir='@rpath'

    else
        # Native macOS build
        EXTRA_LDFLAGS="-mmacosx-version-min=$MIN_VERSION"
        EXTRA_CFLAGS="-mmacosx-version-min=$MIN_VERSION"

        ./configure \
        --prefix="$OUT_DIR" \
        --disable-programs \
        --disable-xlib \
        --disable-lzma \
	    --disable-doc \
	    --enable-network \
	    --enable-shared \
	    --disable-static \
	    --enable-cross-compile \
	    --arch=$ARCH \
	    --cc="clang -arch $ARCH" \
        --extra-cflags="$EXTRA_CFLAGS" \
        --extra-ldflags="$EXTRA_LDFLAGS" \
        --install-name-dir='@rpath'
    fi

    make clean
    make -j"$NPROC"
    make install
    
    # Create frameworks after successful build
    create_frameworks "$PLATFORM" "$ARCH" "$MIN_VERSION"
}

create_xcframework() {
    local framework_name="$1"
    local output_path="$ROOT_DIR/XCFrameworks/${framework_name}.xcframework"
    rm -rf "$output_path"

    echo "Creating XCFramework for $framework_name"

    xcodebuild -create-xcframework \
        -framework "$BUILD_DIR/ios/arm64/framework/${framework_name}.framework" \
        -framework "$BUILD_DIR/tvos/arm64/framework/${framework_name}.framework" \
        -framework "$BUILD_DIR/macos/universal/framework/${framework_name}.framework" \
        -output "$output_path"
}

merge_macos_frameworks() {
    local framework_name="$1"
    local merged_dir="$BUILD_DIR/macos/universal/framework/${framework_name}.framework"
    local arm64_lib="$BUILD_DIR/macos/arm64/framework/${framework_name}.framework/${framework_name}"
    local x86_64_lib="$BUILD_DIR/macos/x86_64/framework/${framework_name}.framework/${framework_name}"

    echo "Merging macOS frameworks for $framework_name..."

    # Create framework directory
    rm -rf "$merged_dir"
    mkdir -p "$merged_dir"

    # Merge binaries
    lipo -create "$arm64_lib" "$x86_64_lib" -output "$merged_dir/${framework_name}"

    # Copy Info.plist and headers
    cp "$BUILD_DIR/macos/arm64/framework/${framework_name}.framework/Info.plist" "$merged_dir/"
    cp -R "$BUILD_DIR/macos/arm64/framework/${framework_name}.framework/Headers" "$merged_dir/"

    echo "Merged universal framework created for $framework_name at $merged_dir"
}

# macOS x86_64
build_target macos x86_64 darwin 15.0 ""

# macOS arm64
build_target macos arm64 darwin 15.0 ""

# iOS arm64
IOS_SDK=$(xcrun --sdk iphoneos --show-sdk-path)
build_target ios arm64 darwin 18.0 "$IOS_SDK"

# tvOS arm64
TVOS_SDK=$(xcrun --sdk appletvos --show-sdk-path)
build_target tvos arm64 darwin 18.0 "$TVOS_SDK"

for lib in libavcodec libavformat libavutil libswresample libswscale; do
    merge_macos_frameworks "$lib"
done

for lib in libavcodec libavformat libavutil libswresample libswscale; do
    create_xcframework "$lib"
done

echo "FFmpeg build and framework creation completed successfully."
