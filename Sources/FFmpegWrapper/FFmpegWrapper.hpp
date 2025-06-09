#ifndef FFmpegWrapper_hpp
#define FFmpegWrapper_hpp

#ifdef __cplusplus
extern "C" {
#endif

void ffmpeg_print_version(void);

int ffmpeg_open_stream(const char* url);
int ffmpeg_read_frame();
void ffmpeg_close();

#ifdef __cplusplus
}
#endif

#endif
