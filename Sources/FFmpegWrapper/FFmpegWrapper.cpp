#include "FFmpegWrapper.hpp"
#include <libavformat/avformat.h>
#include <libavcodec/avcodec.h>
#include <libavutil/imgutils.h>
#include <stdio.h>

static AVFormatContext* fmt_ctx = NULL;
static AVCodecContext* codec_ctx = NULL;
static int video_stream_index = -1;

void ffmpeg_print_version(void) {
    printf("FFmpeg version: %s\n", av_version_info());
}

int ffmpeg_open_stream(const char* url) {
    avformat_network_init();

    if (avformat_open_input(&fmt_ctx, url, NULL, NULL) < 0) {
        fprintf(stderr, "Failed to open input\n");
        return -1;
    }

    if (avformat_find_stream_info(fmt_ctx, NULL) < 0) {
        fprintf(stderr, "Failed to find stream info\n");
        return -1;
    }

    for (unsigned int i = 0; i < fmt_ctx->nb_streams; ++i) {
        if (fmt_ctx->streams[i]->codecpar->codec_type == AVMEDIA_TYPE_VIDEO) {
            video_stream_index = i;
            break;
        }
    }

    if (video_stream_index == -1) {
        fprintf(stderr, "No video stream found\n");
        return -1;
    }

    AVCodecParameters* codecpar = fmt_ctx->streams[video_stream_index]->codecpar;
    const AVCodec* codec = avcodec_find_decoder(codecpar->codec_id);
    if (!codec) {
        fprintf(stderr, "Unsupported codec\n");
        return -1;
    }

    codec_ctx = avcodec_alloc_context3(codec);
    if (!codec_ctx) {
        fprintf(stderr, "Failed to allocate codec context\n");
        return -1;
    }

    if (avcodec_parameters_to_context(codec_ctx, codecpar) < 0) {
        fprintf(stderr, "Failed to copy codec params\n");
        return -1;
    }

    if (avcodec_open2(codec_ctx, codec, NULL) < 0) {
        fprintf(stderr, "Failed to open codec\n");
        return -1;
    }

    printf("Stream opened: resolution %dx%d\n", codec_ctx->width, codec_ctx->height);
    return 0;
}

int ffmpeg_read_frame() {
    AVPacket pkt;
    av_init_packet(&pkt);

    while (av_read_frame(fmt_ctx, &pkt) >= 0) {
        if (pkt.stream_index == video_stream_index) {
            int ret = avcodec_send_packet(codec_ctx, &pkt);
            if (ret < 0) continue;

            AVFrame* frame = av_frame_alloc();
            ret = avcodec_receive_frame(codec_ctx, frame);
            if (ret == 0) {
                printf("Decoded frame: %dx%d, PTS=%ld\n",
                       frame->width, frame->height, frame->pts);
                av_frame_free(&frame);
                av_packet_unref(&pkt);
                return 0;
            }
            av_frame_free(&frame);
        }
        av_packet_unref(&pkt);
    }

    return -1;
}

void ffmpeg_close() {
    avcodec_free_context(&codec_ctx);
    avformat_close_input(&fmt_ctx);
    avformat_network_deinit();
    fmt_ctx = NULL;
    codec_ctx = NULL;
    video_stream_index = -1;
    printf("FFmpeg closed\n");
}

