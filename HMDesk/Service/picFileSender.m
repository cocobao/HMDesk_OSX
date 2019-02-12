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
        
        NSString *threadName = [NSString stringWithFormat:@"mvThread_%zd_%zd", uid, fileId];
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
            MITLog(@"thread is cannel");
            break;
        }
        
        [fileHandle seekToFileOffset:offset];
        NSData *data = [picFileSender readFileHandle:fileHandle offset:offset fileSize:fileSize];
        if (!data) {
            MITLog(@"finish");
            break;
        }
        offset += data.length;
        NSData *reData = [picFileSender resetForSendData:data fid:fileSender.mFileId];
        [picLink sendFileData:reData uid:(uint32_t)fileSender.mUid msgId:0];
//        MITLog(@"send data size:%zd", reData.length);
        usleep(10000);
    }
    
    [fileHandle closeFile];
    
    if (self.m_delegate && [self.m_delegate respondsToSelector:@selector(didSendFinish:)]) {
        [self.m_delegate didSendFinish:fileSender.threadName];
    }
}

+(NSData *)readFileHandle:(NSFileHandle *)handle offset:(NSInteger)offSet fileSize:(NSInteger)fileSize
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

+(NSData *)resetForSendData:(NSData *)pSrc fid:(unsigned long long)fid
{
    int sizeSpace = sizeof(unsigned long long);
    int headerSize = sizeof(stPssProtocolHead);
    NSMutableData *muData = [[NSMutableData alloc] initWithLength:(headerSize+pSrc.length+sizeSpace)];
    
    uint8_t *pDes = (uint8_t *)[muData bytes];
    memcpy(pDes+headerSize, &fid, sizeof(fid));
    memcpy(pDes+headerSize+sizeSpace, [pSrc bytes], pSrc.length);
    return muData;
}

+(NSData *)readFilePartWithPath:(NSString *)filePath apFileId:(NSInteger)apFileId seek:(NSInteger)seek
{
    NSDictionary *info = [UPan_FileMng fileAttriutes:filePath];
    NSInteger fileSize = [info[NSFileSize] integerValue];
    if (fileSize < seek) {
        return nil;
    }
    
    NSFileHandle *fileHandle = [NSFileHandle fileHandleForReadingAtPath:filePath];
    [fileHandle seekToFileOffset:seek];
    NSData *data = [picFileSender readFileHandle:fileHandle offset:seek fileSize:fileSize];
    [fileHandle closeFile];
    
    NSData *reData = [picFileSender resetForSendData:data fid:apFileId];
    return reData;
}
@end
