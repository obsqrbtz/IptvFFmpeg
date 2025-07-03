#import <Foundation/Foundation.h>
#import <CoreVideo/CoreVideo.h>

NS_ASSUME_NONNULL_BEGIN

@interface FFmpegWrapper : NSObject

+ (NSString *)ffmpegVersion;

- (instancetype)initWithURL:(NSString *)urlString;
- (nullable CVPixelBufferRef)getLatestFrame;

@end

NS_ASSUME_NONNULL_END
