//
//  picFileSender.m
//  HMDesk
//
//  Created by admin on 2017/3/8.
//  Copyright © 2017年 ybz. All rights reserved.
//

#import "picFileSender.h"
#import "picLinkObj.h"

static const NSInteger MaxReadSize = (1024*1024);

@interface picFileSender ()
@property (nonatomic, copy) NSString *filePath;
@property (nonatomic, assign) NSInteger mUid;
@property (nonatomic, assign) NSInteger persent;
@property (nonatomic, assign) NSInteger mFileId;
@property (nonatomic, strong) NSThread *mThread;
@end

@implementation picFileSender
-(instancetype)initWithUid:(NSInteger)uid
                  filePath:(NSString *)filePath
                    fileId:(NSInteger)fileId
{
    if (self = [super init]) {
        _filePath = filePath;
        _mUid = uid;
        _mFileId = fileId;
        
        NSString *threadName = [NSString stringWithFormat:@"mvThread_%zd", uid];
        NSThread *thread = [[NSThread alloc] initWithTarget:self selector:@selector(mvThread:) object:self];
        [thread setName:threadName];
        [thread start];
        _mThread = thread;
        _threadName = threadName;
    }
    return self;
}

-(void)cancel
{
    [_mThread cancel];
}

-(void)mvThread:(id)obj
{
    __weak picFileSender *fileSender = (picFileSender *)obj;

    NSDictionary *info = [UPan_FileMng fileAttriutes:fileSender.filePath];
    NSInteger fileSize = [info[NSFileSize] integerValue];
    NSFileHandle *fileHandle = [NSFileHandle fileHandleForReadingAtPath:fileSender.filePath];
    NSInteger offset = 0;
    NSThread *currentThread = [NSThread currentThread];

    for(;;){
        if (currentThread.isCancelled) {
            NSLog(@"thread is cannel");
            break;
        }
        
        [fileHandle seekToFileOffset:offset];
        NSData *data = [self readFileHandle:fileHandle offset:offset fileSize:fileSize];
        if (!data) {
            NSLog(@"finish");
            break;
        }
        offset += data.length;
        NSData *reData = [self resetForSendData:data fid:(int)fileSender.mUid];
        [picLink sendFileData:reData uid:(uint32_t)fileSender.mUid];
        usleep(20000);
    }
}

-(NSData *)readFileHandle:(NSFileHandle *)handle offset:(NSInteger)offSet fileSize:(NSInteger)fileSize
{
    NSInteger readSize = 0;
    if (fileSize - offSet > MaxReadSize) {
        readSize = MaxReadSize;
    }else{
        readSize = fileSize - offSet;
    }
    
    if (readSize <= 0) {
        return nil;
    }
    
    return [handle readDataOfLength:readSize];
}

-(NSData *)resetForSendData:(NSData *)pSrc fid:(int)fid
{
    NSInteger headerSize = sizeof(stPssProtocolHead);
    NSMutableData *muData = [[NSMutableData alloc] initWithLength:(headerSize+pSrc.length+sizeof(int))];
    uint8_t *pDes = (uint8_t *)[muData bytes];
    memcpy(pDes+headerSize+sizeof(NSInteger), [pSrc bytes], pSrc.length);
    memcpy(pDes+headerSize, &fid, sizeof(int));
    return muData;
}
@end
