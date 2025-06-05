#include "FFmpegWrapper.h"
#include <stdio.h>
#include <libavutil/avutil.h>

void ffmpeg_print_version(void) {
    printf("FFmpeg version: %s\n", av_version_info());
}

