//
//  mvPackMaker.m
//  picSimpleSendDeskServer
//
//  Created by admin on 2017/1/22.
//  Copyright © 2017年 ybz. All rights reserved.
//

#import "mvPackMaker.h"

#include "libswscale/swscale.h"
#include "libswresample/swresample.h"
#import "pssProtocolType.h"

#define AV_RB16(x)  ((((const uint8_t*)(x))[0] << 8) | ((const uint8_t*)(x))[1])
#define AV_RB32(x)  ((((const uint8_t*)(x))[0] << 24) | \
                    (((const uint8_t*)(x))[1] << 16) | \
                    (((const uint8_t*)(x))[2] <<  8) | \
                    ((const uint8_t*)(x))[3])

static void avStreamFPSTimeBase(AVStream *st, CGFloat defaultTimeBase, CGFloat *pFPS, CGFloat *pTimeBase)
{
    CGFloat fps, timebase;
    
    if (st->time_base.den && st->time_base.num)
        timebase = av_q2d(st->time_base);
    else if(st->codec->time_base.den && st->codec->time_base.num)
        timebase = av_q2d(st->codec->time_base);
    else
        timebase = defaultTimeBase;
    
    if (st->codec->ticks_per_frame != 1) {
        NSLog(@"WARNING: st.codec.ticks_per_frame=%d", st->codec->ticks_per_frame);
        //timebase *= st->codec->ticks_per_frame;
    }
    
    if (st->avg_frame_rate.den && st->avg_frame_rate.num)
        fps = av_q2d(st->avg_frame_rate);
    else if (st->r_frame_rate.den && st->r_frame_rate.num)
        fps = av_q2d(st->r_frame_rate);
    else
        fps = 1.0 / timebase;
    
    if (pFPS)
        *pFPS = fps;
    if (pTimeBase)
        *pTimeBase = timebase;
}

@interface mvPackMaker ()
{
    AVFormatContext     *_formatCtx;
    AVCodecContext      *_videoCodecCtx;
    AVCodecContext      *_audioCodecCtx;
    AVFrame             *_videoFrame;
    AVFrame             *_audioFrame;
    AVStream            *_videoStream;
    AVStream            *_audioStream;
    CGFloat             _videoTimeBase;
    CGFloat             _audioTimeBase;
    NSData             *_PpsSps;
}
@end

static const uint8_t nalu_header[4] = {0, 0, 0, 1};

@implementation mvPackMaker
-(instancetype)init
{
    self = [super init];
    if (self) {
        _PpsSps = nil;
        _videoStream = NULL;
        _audioCodecCtx = NULL;
        _videoCodecCtx = NULL;
        av_register_all();
    }
    return self;
}

-(BOOL)openFile:(NSString *)file
{
    //输出ffmpeg的版本信息
    const char *v = av_version_info();
    NSLog(@"ffmpeg verion info, %s", v);
    
    //打开视频文件
    kxMovieError ret = [self openInput:file];
    if (ret != kxMovieErrorNone) goto openFail;
    
    //打开媒体
    ret = [self openMedia:AVMEDIA_TYPE_VIDEO];
    if (ret != kxMovieErrorNone) goto openFail;

    ret = [self openMedia:AVMEDIA_TYPE_AUDIO];
    if (ret != kxMovieErrorNone) goto openFail;
    
    return YES;
openFail:
    [self closeFile];
    return NO;
}

-(kxMovieError)openInput:(NSString *)path
{
    AVFormatContext *formatCtx = NULL;
    
    formatCtx = avformat_alloc_context();
    if (formatCtx == NULL) {
        return kxMovieErrorOpenFile;
    }
    
    //打开视频文件
    int ret = avformat_open_input(&formatCtx, [path cStringUsingEncoding:NSUTF8StringEncoding], NULL, NULL);
    if (ret < 0) {
        avformat_free_context(formatCtx);
        return kxMovieErrorOpenFile;
    }
    
    //查找文件流信息
    ret = avformat_find_stream_info(formatCtx, NULL);
    if (ret < 0) {
        avformat_close_input(&formatCtx);
        return kxMovieErrorStreamInfoNotFound;
    }
    
    if(formatCtx->duration != AV_NOPTS_VALUE){
        int hours, mins, secs, us;
        int64_t duration = formatCtx->duration + 5000;
        secs = (int)(duration / AV_TIME_BASE);
        us = duration % AV_TIME_BASE;
        mins = secs / 60;
        secs %= 60;
        hours = mins/ 60;
        mins %= 60;
        
        _videoInfo.duration = (int)(formatCtx->duration/AV_TIME_BASE);
        
        printf("视频总时长----%02d:%02d:%02d.%02d, duration:%zd\n",
               hours, mins, secs, (100 * us) / AV_TIME_BASE,
               _videoInfo.duration);
    }
    
    //dump只是个调试函数，输出文件的音、视频流的基本信息了，帧率、分辨率、音频采样等等
    av_dump_format(formatCtx, 0, [path.lastPathComponent cStringUsingEncoding: NSUTF8StringEncoding], false);
    _formatCtx = formatCtx;
    return kxMovieErrorNone;
}

-(kxMovieError )openMedia:(NSInteger)mediaType
{
    for (int i = 0; i < _formatCtx->nb_streams; i++) {
        enum AVMediaType type = _formatCtx->streams[i]->codec->codec_type;
        if (type == mediaType) {
            switch (mediaType) {
                case AVMEDIA_TYPE_VIDEO:
                {
                    int pos = _formatCtx->streams[i]->disposition;
                    if ((pos & AV_DISPOSITION_ATTACHED_PIC) == 0) {
                        kxMovieError ret = [self openVideoStream:_formatCtx->streams[i]];
                        if (ret != kxMovieErrorNone) {
                            return ret;
                        }
                    }
                }
                    break;
                case AVMEDIA_TYPE_AUDIO:
                {
                    kxMovieError ret = [self openAudioStream:_formatCtx->streams[i]];
                    if (ret != kxMovieErrorNone) {
                        return ret;
                    }
                }
                    break;
                case AVMEDIA_TYPE_SUBTITLE:
                    break;
                default:
                    break;
            }
        }
    }
    return kxMovieErrorNone;
}

//打开视频文件流
-(kxMovieError)openVideoStream:(AVStream *)avStream
{
    // get a pointer to the codec context for the video stream
    AVCodecContext *codecCtx = avStream->codec;
    
    //根据AVCodecID 查找支持该视频格式的解码器
    AVCodec *codec = avcodec_find_decoder(codecCtx->codec_id);
    if (codec == NULL) {
        return kxMovieErrorCodecNotFound;
    }
    _videoInfo.mv_codec_id = codecCtx->codec_id;
    
    //打开解码器
    if (avcodec_open2(codecCtx, codec, NULL) < 0) {
        return kxMovieErrorOpenCodec;
    }
    //申请帧缓存
    _videoFrame = av_frame_alloc();
    if (!_videoFrame) {
        avcodec_close(codecCtx);
        return kxMovieErrorAllocateFrame;
    }
    
    CGFloat fps;
    avStreamFPSTimeBase(avStream, 0.04, (CGFloat *)&fps, &_videoTimeBase);
    _videoCodecCtx = codecCtx;
    _videoStream = avStream;
    _videoInfo.width = codecCtx->width;
    _videoInfo.height = codecCtx->height;
    _videoInfo.fps = fps;
    NSLog(@"width:%zd, height:%zd, fps:%0.3f", _videoInfo.width, _videoInfo.height, _videoInfo.fps);
    
    [self mp4FilterSpsPps:codecCtx->extradata];
    return kxMovieErrorNone;
}

//打开音频文件流
-(kxMovieError)openAudioStream:(AVStream *)avStream
{
    // get a pointer to the codec context for the audio stream
    AVCodecContext *codecCtx = avStream->codec;
    
    //根据AVCodecID 查找解码器
    AVCodec *codec = avcodec_find_decoder(codecCtx->codec_id);
    if (codec == NULL) {
        return kxMovieErrorCodecNotFound;
    }
    
    //打开解码器
    if (avcodec_open2(codecCtx, codec, NULL) < 0) {
        return kxMovieErrorOpenCodec;
    }
    
    _audioFrame = av_frame_alloc();
    if (!_audioFrame) {
        avcodec_close(codecCtx);
        return kxMovieErrorAllocateFrame;
    }
    
    _audioStream = avStream;
    _audioCodecCtx = codecCtx;
    avStreamFPSTimeBase(_audioStream, 0.025, 0, &_audioTimeBase);
    NSLog(@"audio codec id:%d smr: %.d fmt: %d chn: %d tb: %f",
          codecCtx->codec_id,
          _audioCodecCtx->sample_rate,
          _audioCodecCtx->sample_fmt,
          _audioCodecCtx->channels,
          _audioTimeBase);
    
    _audioInfo.av_codec_id = codecCtx->codec_id;
    _audioInfo.sampleFormat = codecCtx->sample_fmt;
    _audioInfo.sample_rate = codecCtx->sample_rate;
    _audioInfo.channels = codecCtx->channels;
    
    return kxMovieErrorNone;
}

//提取pps, sps
-(int)mp4FilterSpsPps:(uint8_t *)exeData
{
    if (exeData == NULL || _videoCodecCtx == NULL) {
        return AVERROR(EINVAL);
    }
    
    //跳过avcc box type
    uint8_t *extradata = exeData + 4;
    uint8_t leng_size = (*extradata++ & 0x3) + 1;
    if (leng_size == 3) {
        NSLog(@"averror, einval, %d", AVERROR(EINVAL));
        return AVERROR(EINVAL);
    }
    
    uint8_t unit_nb = *extradata++ & 0x1f;
    uint8_t sps_seen = 0;
    uint8_t pps_seen = 0;
    uint8_t sps_done = 0;
    uint16_t unit_size = 0;
    uint64_t total_size = 0;
    uint8_t *outm = NULL;
    
    if (!unit_nb) {
        goto pps;
    }else{
        sps_seen = 1;
    }
    
    while (unit_nb--) {
        void *tmp;
        
        unit_size = AV_RB16(extradata);
        total_size += unit_size + 4;
        if (total_size > INT_MAX - FF_INPUT_BUFFER_PADDING_SIZE ||
            extradata + 2 + unit_size > _videoCodecCtx->extradata+_videoCodecCtx->extradata_size) {
            av_free(outm);
            return AVERROR(EINVAL);
        }
        
        tmp = av_realloc(outm, total_size + FF_INPUT_BUFFER_PADDING_SIZE);
        if (!tmp) {
            av_free(outm);
            return AVERROR(ENOMEM);
        }
        outm = tmp;
        //拷贝nalu头
        memcpy(outm+total_size-unit_size-4, nalu_header, 4);
        //拷贝sps,pps数据
        memcpy(outm+total_size-unit_size, extradata+2, unit_size);
        extradata += 2+unit_size;
    pps:
        if (!unit_nb && !sps_done++) {
            unit_nb = *extradata++;
            if (unit_nb) {
                pps_seen = 1;
            }
        }
    }
    
    if (outm) {
        memset(outm + total_size, 0, FF_INPUT_BUFFER_PADDING_SIZE);
        _PpsSps = [NSData dataWithBytes:outm length:total_size];
        av_free(outm);
    }
    
    if (!sps_seen) {
        av_log(_videoCodecCtx, AV_LOG_WARNING, "Warning: SPS NALU missing or invalid. The resulting stream may not play.\n");
    }
    
    if (!pps_seen) {
        av_log(_videoCodecCtx, AV_LOG_WARNING, "Warning: PPS NALU missing or invalid. The resulting stream may not play.\n");
    }
    
    return 0;
}

//读出一帧数据
-(int)avReadFrame:(NSData **)outPack type:(NSInteger*)type
{
    AVPacket packet;
reReadPack:
    if (av_read_frame(_formatCtx, &packet) < 0) {
        NSLog(@"av EOF");
        return 0;
    }
    
    if (packet.stream_index == _videoStream->index){
        //视频数据包
        *type = AVMEDIA_TYPE_VIDEO;
    }else if(packet.stream_index == _audioStream->index){
        //音频数据包
        *type = AVMEDIA_TYPE_AUDIO;
    }else{
        NSLog(@"stream_index invalid");
        memset(&packet, 0, sizeof(AVPacket));
        goto reReadPack;
    }
    int pktSize = packet.size+sizeof(stPssProtocolHead);
    
    uint8_t *pBuf = NULL;
    NSMutableData *data = [[NSMutableData alloc] initWithLength:pktSize];
    pBuf = (uint8_t *)(data.bytes+sizeof(stPssProtocolHead));
    
    if (packet.stream_index == _videoStream->index) {
        int skipSize = 0;
        //I帧
        if (packet.flags == 1) {
            pktSize += _PpsSps.length;
            skipSize += _PpsSps.length;
            [data setLength:pktSize];
            //拷贝pps,sps数据
            memcpy(pBuf, _PpsSps.bytes, _PpsSps.length);
        }
        //拷贝nalu头
        memcpy(pBuf+skipSize, nalu_header, 4);
        skipSize += 4;
        //拷贝视频数据
        memcpy(pBuf+skipSize, packet.data+4, packet.size);
    }else{
        //拷贝音频数据
        memcpy(pBuf, packet.data, packet.size);
    }
    
    *outPack = data;
    return pktSize;
}

//关闭视频流
-(void)closeVideoStream
{
    if (_PpsSps) {
        _PpsSps = NULL;
    }
    
    if (_videoFrame) {
        av_free(_videoFrame);
        _videoFrame = NULL;
    }
    
    if (_videoCodecCtx) {
        avcodec_close(_videoCodecCtx);
        _videoCodecCtx = NULL;
    }
    
    _videoStream = NULL;
    
    if (_formatCtx) {
        _formatCtx->interrupt_callback.opaque = NULL;
        _formatCtx->interrupt_callback.callback = NULL;
        avformat_close_input(&_formatCtx);
        _formatCtx = NULL;
    }
}

-(void)closeAudioStream
{
    if (_audioFrame) {
        av_free(_audioFrame);
        _audioFrame = NULL;
    }
    
    if (_audioCodecCtx) {
        avcodec_close(_audioCodecCtx);
        _audioCodecCtx = NULL;
    }
    
    _audioStream = NULL;
}

-(void)closeFile
{
    [self closeAudioStream];
    [self closeVideoStream];
}

- (void) dealloc
{
    [self closeFile];
}
@end
