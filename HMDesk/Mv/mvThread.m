//
//  mvThread.m
//  picSimpleSendDeskServer
//
//  Created by admin on 2017/2/4.
//  Copyright © 2017年 ybz. All rights reserved.
//

#import "mvThread.h"
#import "mvPackMaker.h"
#import "picLinkObj.h"

@interface mvThread ()
@property (nonatomic, strong) NSMutableDictionary *mThreadsDict;
@end

@implementation mvThread
-(instancetype)init
{
    if (self = [super init]) {
        _mThreadsDict = [NSMutableDictionary dictionary];
    }
    return self;
}

//添加一个视频线程
-(void)addMvThread:(uint)uid file:(NSString *)file
{
    NSString *threadName = [NSString stringWithFormat:@"mvThread_%d", uid];
    if (_mThreadsDict[threadName]) {
        NSThread *thread = _mThreadsDict[threadName];
        if (!thread.cancelled) {
            NSLog(@"thread is running, and cut off");
            [thread cancel];
        }
    }

    mvPackMaker *mvMaker = [[mvPackMaker alloc] init];
    [mvMaker openFile:file];
    
    NSDictionary *dict = @{
                           ptl_fps:@(mvMaker.videoInfo.fps),
                           ptl_duration:@(mvMaker.videoInfo.duration),
                           ptl_width:@(mvMaker.videoInfo.width),
                           ptl_height:@(mvMaker.videoInfo.height),
                           ptl_mvCodecId:@(mvMaker.videoInfo.mv_codec_id),
                           ptl_avCodecId:@(mvMaker.audioInfo.av_codec_id),
                           ptl_sampleFmt:@(mvMaker.audioInfo.sampleFormat),
                           ptl_sampleRate:@(mvMaker.audioInfo.sample_rate),
                           ptl_channels:@(mvMaker.audioInfo.channels),
                           };
    WeakSelf(weakSelf);
    [picLink NetApi_VideoWithUid:uid info:dict block:^(NSDictionary *message, NSError *error) {
        if (error) {
            return;
        }
        
        NSDictionary *dict = @{
                               @"uid":@(uid),
                               @"file":file,
                               @"mvMaker":mvMaker,
                               };
        
        NSThread *thread = [[NSThread alloc] initWithTarget:self selector:@selector(mvThread:) object:dict];
        [thread setName:threadName];
        [thread start];
        
        [weakSelf.mThreadsDict setValue:thread forKey:thread.name];
    }];
}

//移除视频线程
-(void)removeMvThread:(uint)uid
{
    NSString *threadName = [NSString stringWithFormat:@"mvThread_%d", uid];
    if (!_mThreadsDict[threadName]) {
        NSLog(@"thread not exist");
        return;
    }
    NSLog(@"thread %@ exit", threadName);
    NSThread *thread = _mThreadsDict[threadName];
    [thread cancel];
}

-(void)mvThread:(id)obj
{
    NSDictionary *dict = obj;
    
    NSInteger uid = [dict[@"uid"] integerValue];
    mvPackMaker *mvMaker = dict[@"mvMaker"];
    NSString *host = [picLink getIpWithUid:(uint32_t)uid];
    NSString *threadName = [NSString stringWithFormat:@"mvThread_%zd", uid];

    NSThread *currentThread = [NSThread currentThread];
    
    int f = 0;
    for (;;) {
        if (currentThread.isCancelled) {
            NSLog(@"thread is cannel");
            break;
        }
        usleep(20000);
        
        NSData *frameBuffer = NULL;
        NSInteger type = 0;
        [mvMaker avReadFrame:&frameBuffer type:&type];
        if (frameBuffer == NULL) {
            NSLog(@"av frame buff NULL");
            break;
        }
        f += 1;
        //        NSLog(@"av size:%zd, index:%d, type:%zd", frameBuffer.length-sizeof(stPssProtocolHead), f, type);
        if (type == 0) {
            [picLink sendMvData:frameBuffer toHost:host];
        }else if(type == 1){
            [picLink sendAuData:frameBuffer toHost:host];
        }
    }
    [mvMaker closeFile];
    [_mThreadsDict removeObjectForKey:threadName];
    NSLog(@"uid %zd exit mv thread", uid);
}




@end
