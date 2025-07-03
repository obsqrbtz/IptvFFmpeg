#import "FFmpegWrapper.h"
#import <libavutil/avutil.h>
#import <libavformat/avformat.h>
#import <libavcodec/avcodec.h>
#import <libswscale/swscale.h>
#import <libavutil/imgutils.h>

@interface FFmpegWrapper ()
{
    AVFormatContext *formatCtx;
    AVCodecContext *codecCtx;
    AVFrame *frame;
    AVPacket *packet;
    struct SwsContext *swsCtx;
    int videoStreamIndex;

    CVPixelBufferRef pixelBuffer;

    dispatch_queue_t decodeQueue;
    CVPixelBufferRef latestFrame;

    BOOL stopDecoding;
    NSLock *frameLock;
}

@property (nonatomic, strong) NSString *urlString;

@end

@implementation FFmpegWrapper

+ (NSString *)ffmpegVersion {
    const char *versionCString = av_version_info();
    return [NSString stringWithUTF8String:versionCString];
}

- (instancetype)initWithURL:(NSString *)urlString {
    if (self = [super init]) {
        self.urlString = urlString;
        [self setupPlayer];
        [self startDecodingLoop];
    }
    return self;
}

- (void)dealloc {
    stopDecoding = YES;
    if (decodeQueue) {
        dispatch_sync(decodeQueue, ^{}); // wait for decode loop to exit
    }

    if (latestFrame) {
        CVPixelBufferRelease(latestFrame);
        latestFrame = NULL;
    }

    if (pixelBuffer) {
        CVPixelBufferRelease(pixelBuffer);
        pixelBuffer = NULL;
    }

    if (frame) {
        av_frame_free(&frame);
        frame = NULL;
    }
    if (packet) {
        av_packet_free(&packet);
        packet = NULL;
    }
    if (codecCtx) {
        avcodec_free_context(&codecCtx);
        codecCtx = NULL;
    }
    if (formatCtx) {
        avformat_close_input(&formatCtx);
        formatCtx = NULL;
    }
    if (swsCtx) {
        sws_freeContext(swsCtx);
        swsCtx = NULL;
    }
}

- (void)setupPlayer {
    avformat_network_init();

    formatCtx = avformat_alloc_context();
    if (avformat_open_input(&formatCtx, [self.urlString UTF8String], NULL, NULL) != 0) {
        NSLog(@"Could not open input");
        return;
    }
    if (avformat_find_stream_info(formatCtx, NULL) < 0) {
        NSLog(@"Could not find stream info");
        return;
    }

    videoStreamIndex = -1;
    for (unsigned int i = 0; i < formatCtx->nb_streams; i++) {
        if (formatCtx->streams[i]->codecpar->codec_type == AVMEDIA_TYPE_VIDEO) {
            videoStreamIndex = i;
            break;
        }
    }
    if (videoStreamIndex == -1) {
        NSLog(@"No video stream found");
        return;
    }

    AVCodecParameters *codecpar = formatCtx->streams[videoStreamIndex]->codecpar;
    AVCodec *codec = avcodec_find_decoder(codecpar->codec_id);
    if (!codec) {
        NSLog(@"Unsupported codec");
        return;
    }

    codecCtx = avcodec_alloc_context3(codec);
    if (avcodec_parameters_to_context(codecCtx, codecpar) < 0) {
        NSLog(@"Failed to copy codec params");
        return;
    }
    if (avcodec_open2(codecCtx, codec, NULL) < 0) {
        NSLog(@"Failed to open codec");
        return;
    }

    frame = av_frame_alloc();
    packet = av_packet_alloc();

    // Setup sws_scale to convert to BGRA (native CVPixelBuffer format)
    swsCtx = sws_getContext(codecCtx->width,
                            codecCtx->height,
                            codecCtx->pix_fmt,
                            codecCtx->width,
                            codecCtx->height,
                            AV_PIX_FMT_BGRA,
                            SWS_BILINEAR,
                            NULL,
                            NULL,
                            NULL);

    // Create reusable pixel buffer once:
    NSDictionary *pixelBufferAttributes = @{
        (id)kCVPixelBufferCGImageCompatibilityKey: @YES,
        (id)kCVPixelBufferCGBitmapContextCompatibilityKey: @YES,
        (id)kCVPixelBufferIOSurfacePropertiesKey: @{},
    };

    CVReturn ret = CVPixelBufferCreate(kCFAllocatorDefault,
                                       codecCtx->width,
                                       codecCtx->height,
                                       kCVPixelFormatType_32BGRA,
                                       (__bridge CFDictionaryRef)pixelBufferAttributes,
                                       &pixelBuffer);
    if (ret != kCVReturnSuccess || pixelBuffer == NULL) {
        NSLog(@"Failed to create reusable CVPixelBuffer");
        return;
    }

    // Initialize frame lock and dispatch queue
    frameLock = [[NSLock alloc] init];
    decodeQueue = dispatch_queue_create("com.example.ipvdecoder.decode", DISPATCH_QUEUE_SERIAL);
    stopDecoding = NO;
}

- (void)startDecodingLoop {
    __weak typeof(self) weakSelf = self;
    dispatch_async(decodeQueue, ^{
        [weakSelf decodingLoop];
    });
}

- (void)decodingLoop {
    while (!stopDecoding) {
        int ret = av_read_frame(formatCtx, packet);
        if (ret < 0) {
            avcodec_send_packet(codecCtx, NULL); // flush
            while (avcodec_receive_frame(codecCtx, frame) == 0) {
                [self convertAndStoreFrame:frame];
            }
            break;
        }

        if (packet->stream_index == videoStreamIndex) {
            int sendRet = avcodec_send_packet(codecCtx, packet);
            if (sendRet < 0) {
                NSLog(@"Error sending packet: %d", sendRet);
            }
            while (avcodec_receive_frame(codecCtx, frame) == 0) {
                [self convertAndStoreFrame:frame];
            }
        }
        av_packet_unref(packet);
    }
}

- (void)convertAndStoreFrame:(AVFrame *)frameIn {
    // NSLog(@"convertAndStoreFrame: frame size %d x %d", frameIn->width, frameIn->height);

    if (!swsCtx) {
        swsCtx = sws_getContext(
            frameIn->width,
            frameIn->height,
            (enum AVPixelFormat)frameIn->format,
            frameIn->width,
            frameIn->height,
            AV_PIX_FMT_BGRA,
            SWS_FAST_BILINEAR,
            NULL,
            NULL,
            NULL);
    }

    CVPixelBufferRef pixelBuffer = NULL;

    NSDictionary *pixelBufferAttributes = @{
        (NSString*)kCVPixelBufferIOSurfacePropertiesKey: @{}
    };

    CVReturn status = CVPixelBufferCreate(
        kCFAllocatorDefault,
        frameIn->width,
        frameIn->height,
        kCVPixelFormatType_32BGRA,
        (__bridge CFDictionaryRef)pixelBufferAttributes,
        &pixelBuffer);

    if (status != kCVReturnSuccess) {
        NSLog(@"Failed to create CVPixelBuffer: %d", status);
        return;
    }

    CVPixelBufferLockBaseAddress(pixelBuffer, 0);
    uint8_t *dest = (uint8_t *)CVPixelBufferGetBaseAddress(pixelBuffer);

    uint8_t *destPlanes[4] = { dest, NULL, NULL, NULL };
    int destStride[4] = { (int)CVPixelBufferGetBytesPerRow(pixelBuffer), 0, 0, 0 };

    int result = sws_scale(
        swsCtx,
        (const uint8_t * const *)frameIn->data,
        frameIn->linesize,
        0,
        frameIn->height,
        destPlanes,
        destStride);

    CVPixelBufferUnlockBaseAddress(pixelBuffer, 0);

    if (result <= 0) {
        NSLog(@"sws_scale failed");
        CVPixelBufferRelease(pixelBuffer);
        return;
    }

    [frameLock lock];
    if (latestFrame) {
        CVPixelBufferRelease(latestFrame);
    }
    latestFrame = pixelBuffer;
    [frameLock unlock];
}

- (CVPixelBufferRef)getLatestFrame {
    [frameLock lock];
    if (!latestFrame) {
        [frameLock unlock];
        return NULL;
    }
    CVPixelBufferRef frameToReturn = CVPixelBufferRetain(latestFrame);
    [frameLock unlock];
    return frameToReturn;
}

@end
