// swift-tools-version:6.0.3
import PackageDescription

let package = Package(
    name: "IptvFFmpeg",
    platforms: [.macOS(.v15), .iOS(.v18)],
    products: [
        .library(
            name: "IptvFFmpeg", 
            targets: ["IptvFFmpeg"]),
        .library(
            name: "FFmpegWrapper",
            targets: ["FFmpegWrapper"]
        ),
    ],
    targets: [
        .target(
            name: "FFmpegWrapper",
            dependencies: [],
            path: "Sources/FFmpegWrapper",
            publicHeadersPath: ".",
            cxxSettings: [
                .headerSearchPath("../../FFmpeg/build/include"),
                .unsafeFlags(["-IFFmpeg/build/include"]),
                .unsafeFlags(["-std=c++20"])
            ],
            linkerSettings: [
                .unsafeFlags([
                    "FFmpeg/build/lib/libavformat.a",
                    "FFmpeg/build/lib/libavcodec.a",
                    "FFmpeg/build/lib/libavutil.a",
                    "FFmpeg/build/lib/libswscale.a",
                    "FFmpeg/build/lib/libswresample.a",
                    "-lz", "-lm"
                ])
            ]
        ),
        .target(
            name: "IptvFFmpeg",
            dependencies: ["FFmpegWrapper"],
            path: "Sources/IptvFFmpeg",
                linkerSettings: [
                .unsafeFlags(["-LFFmpeg/build/lib"]),
                .linkedFramework("AudioToolbox"),
                .linkedFramework("VideoToolbox"),
                .linkedFramework("CoreVideo"),
                .linkedFramework("CoreMedia"),
                .linkedLibrary("iconv"),
                .linkedLibrary("bz2"),
                .linkedLibrary("lzma")
    ]
        )
    ]
)

