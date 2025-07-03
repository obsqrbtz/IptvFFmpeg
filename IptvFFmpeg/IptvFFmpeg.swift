import Foundation

public func ffmpegVer() -> String {
    return FFmpegWrapper.ffmpegVersion()
}

public class IptvPlayer {
    private let objcPlayer: FFmpegWrapper

    public init(url: String) {
        self.objcPlayer = FFmpegWrapper(url: url)
    }

    public func getNextFrame() -> CVPixelBuffer? {
        guard let pixelBuffer = objcPlayer.getLatestFrame() else {
            return nil
        }
        return pixelBuffer.takeRetainedValue()
    }
}
