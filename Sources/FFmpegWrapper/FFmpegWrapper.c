#include "FFmpegWrapper.h"
#include <stdio.h>
#include <libavformat/avformat.h>

void ffmpeg_print_version(void) {
    printf("FFmpeg version: %d.%d.%d\n", 
           LIBAVFORMAT_VERSION_MAJOR, 
           LIBAVFORMAT_VERSION_MINOR, 
           LIBAVFORMAT_VERSION_MICRO);
}

