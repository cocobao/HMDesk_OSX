//
//  picFileSendrMgr.m
//  HMDesk
//
//  Created by admin on 2017/3/8.
//  Copyright © 2017年 ybz. All rights reserved.
//

#import "picFileExchangeMgr.h"
#import "picFileSender.h"
#import "picFileRecver.h"
#import "pssProtocolType.h"
#import "picLinkObj.h"

@interface picFileExchangeMgr ()<picFileSenderDelegate, FileRecverDelegate>
@property (nonatomic, strong) NSMutableDictionary *dictSenders;
@property (nonatomic, strong) NSMutableDictionary *dictRecvers;
@end

@implementation picFileExchangeMgr
__strong static id sharedInstance = nil;
+ (id)shareInstance
{
    static dispatch_once_t pred = 0;
    dispatch_once(&pred, ^{
        sharedInstance = [[self alloc] init];
    });
    return sharedInstance;
}

+ (id)allocWithZone:(NSZone *)zone
{
    @synchronized(self) {
        if (sharedInstance == nil) {
            sharedInstance = [super allocWithZone:zone];
            return sharedInstance;
        }
    }
    return sharedInstance;
}

- (id)copyWithZone:(NSZone *)zone
{
    return self;
}

-(instancetype)init
{
    if (self = [super init]) {
        _dictSenders = [NSMutableDictionary dictionaryWithCapacity:10];
        _dictRecvers = [NSMutableDictionary dictionaryWithCapacity:10];
        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(clientDisconnect:)
                                                     name:kNotificationClientDisconnect
                                                   object:nil];
        [picLink addTcpDelegate:self];
    }
    return self;
}

-(void)clientDisconnect:(NSNotification *)notify
{
    NSDictionary *dict = notify.object;
    NSInteger uid = [dict[ptl_uid] integerValue];
    NSArray *arrAllKeys = [self.dictSenders allKeys];
    for (NSString *key in arrAllKeys) {
        picFileSender *fs = self.dictSenders[key];
        if (fs.mUid == uid) {
            [fs cancel];
            [self.dictSenders removeObjectForKey:key];
            break;
        }
    }
}

-(NSDictionary *)createFile:(NSString *)fileName
{
    NSArray *arrSrcFile = [UPan_FileMng ContentOfPath:_mNowPath];
    NSPredicate *predicate = [NSPredicate predicateWithFormat:@"SELF BEGINSWITH %@", fileName];
    NSArray *arrTmp = [arrSrcFile filteredArrayUsingPredicate:predicate];
    if (arrTmp.count > 0) {
        //创建副本文件
        fileName = [NSString stringWithFormat:@"%@-副本%zd", fileName, arrTmp.count];
    }
    
    NSString *createPath = [_mNowPath stringByAppendingPathComponent:fileName];
    [UPan_FileMng createFile:createPath];
    NSMutableDictionary *dict = [NSMutableDictionary dictionaryWithDictionary:[UPan_FileMng fileAttriutes:createPath]];
    [dict setValue:createPath forKey:ptl_filePath];
    return dict;
}

-(void)addSendingUid:(NSInteger)uid filePath:(NSString *)filePath fileId:(NSInteger)fileId
{
    picFileSender *fs = [[picFileSender alloc] initWithUid:uid filePath:filePath fileId:fileId];
    if(self.dictSenders[fs.threadName]){
        return;
    }
    self.dictSenders[fs.threadName] = fs;
    fs.m_delegate = self;
    NSLog(@"add file sending:%@", filePath);
}

-(void)addRecvingUid:(NSInteger)uid filePath:(NSString *)filePath fileId:(NSInteger)fileId fileSize:(unsigned long long)fileSize
{
    picFileRecver *fr = [[picFileRecver alloc] initWithUid:uid FileId:fileId filePath:filePath fileSize:fileSize];
    fr.m_delegate = self;
    NSString *key = [NSString stringWithFormat:@"%zd_%zd", uid, fileId];
    _dictRecvers[key] = fr;
}

-(void)didSendFinish:(NSString *)threadName
{
    if (self.dictSenders[threadName]) {
        picFileSender *fs = self.dictSenders[threadName];
        [self.dictSenders removeObjectForKey:threadName];
        [fs cancel];
    }
}

-(void)didRecvFileFinish:(NSInteger)uid fileId:(NSInteger)fileId
{
    NSString *key = [NSString stringWithFormat:@"%zd_%zd", uid, fileId];
    if (_dictRecvers[key]) {
        [_dictRecvers removeObjectForKey:key];
    }
    NSLog(@"recv file %zd finish", fileId);
}

- (void)NetRecvFileUid:(NSInteger)uid fileId:(unsigned long long)fileId Data:(NSData *)data
{
    NSLog(@"recv data:%zd", data.length);
    
    NSString *key = [NSString stringWithFormat:@"%zd_%zd", uid, fileId];
    if (_dictRecvers[key]) {
        picFileRecver *fr = _dictRecvers[key];
        [fr writeFileData:data];
    }
}

- (void)NetTcpCallback:(pssHSMmsg *)receData error:(NSError *)error
{
    if (error) {
        NSLog(@"net call error:%@", error);
        return;
    }
    
    stPssProtocolHead *head = (stPssProtocolHead *)receData.sendData.bytes;
    
    if (head->type == emPssProtocolType_ApplyRecvFile){
        if (!_mNowPath) {
            return;
        }
        NSString *fileName = receData.body[ptl_fileName];
        unsigned long long fileSize = [receData.body[ptl_fileSize] longLongValue];
        NSDictionary *dict = [self createFile:fileName];
        NSInteger fileId = [dict[NSFileSystemFileNumber] integerValue];
        if (fileId <= 0) {
            NSLog(@"创建文件失败");
            [picLink NetApi_FailAckWithUid:head->uid msgId:head->msgId type:head->type errCode:401 msg:@"创建文件失败"];
            return;
        }
        [self addRecvingUid:head->uid
                   filePath:dict[ptl_filePath]
                     fileId:fileId
                   fileSize:fileSize];
        [picLink NetApi_ApplyRecvFileAckWithUid:head->uid msgId:head->msgId fileId:fileId];
    }
}
@end