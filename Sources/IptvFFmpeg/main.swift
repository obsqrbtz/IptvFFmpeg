import FFmpegWrapper
import Foundation

let streamURL = "https://bloomberg-bloombergtv-1-it.samsung.wurl.tv/manifest/playlist.m3u8"

if ffmpeg_open_stream(streamURL) == 0 {
    print("Stream opened successfully")

    for _ in 0..<100 {
        if ffmpeg_read_frame() != 0 {
            print("Stream ended or error.")
            break
        }
        usleep(60_000) // ~60 fps
    }

    ffmpeg_close()
} else {
    print("Failed to open stream")
}