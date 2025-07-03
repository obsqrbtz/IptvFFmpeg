#import "FFmpegWrapper.h"
#import <libavutil/avutil.h>

@implementation FFmpegWrapper

+ (NSString *)ffmpegVersion {
    const char *versionCString = av_version_info();
    return [NSString stringWithUTF8String:versionCString];
}

@end
