//
//  mvPackMaker.h
//  picSimpleSendDeskServer
//
//  Created by admin on 2017/1/22.
//  Copyright © 2017年 ybz. All rights reserved.
//

#import <Foundation/Foundation.h>
#include "libavformat/avformat.h"

typedef enum {
    kxMovieErrorNone,
    kxMovieErrorOpenFile,
    kxMovieErrorStreamInfoNotFound,
    kxMovieErrorStreamNotFound,
    kxMovieErrorCodecNotFound,
    kxMovieErrorOpenCodec,
    kxMovieErrorAllocateFrame,
    kxMovieErroSetupScaler,
    kxMovieErroReSampler,
    kxMovieErroUnsupported,
} kxMovieError;

#pragma pack(1)
typedef struct {
    float fps;
    int64_t duration;
    int width;
    int height;
    int mv_codec_id;
}stVideoInfo;

typedef struct
{
    int av_codec_id;
    int sample_rate;
    int channels;
    enum AVSampleFormat sampleFormat;
}stAudioInfo;
#pragma pack()

@interface mvPackMaker : NSObject
@property (readonly, nonatomic, assign) stVideoInfo videoInfo;
@property (readonly, nonatomic, assign) stAudioInfo audioInfo;

-(BOOL)openFile:(NSString *)file;
-(void)closeFile;
-(int)avReadFrame:(NSData **)outPack type:(NSInteger*)type;
@end
