// swift-tools-version:6.0.3
import PackageDescription

let package = Package(
    name: "IptvFFmpeg",
    platforms: [.macOS(.v15)],
    products: [
        .executable(name: "IptvFFmpeg", targets: ["IptvFFmpeg"]),
    ],
    targets: [
        .target(
            name: "FFmpegWrapper",
            dependencies: [],
            path: "Sources/FFmpegWrapper",
            publicHeadersPath: ".",
            cSettings: [
                .headerSearchPath("../../FFmpeg/build/include"),
                .unsafeFlags(["-IFFmpeg/build/include"])
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
        .executableTarget(
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

