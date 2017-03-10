//
//  picFileSendrMgr.m
//  HMDesk
//
//  Created by admin on 2017/3/8.
//  Copyright © 2017年 ybz. All rights reserved.
//

#import "picFileSendrMgr.h"
#import "picFileSender.h"

@interface picFileSendrMgr ()<picFileSenderDelegate>
@property (nonatomic, strong) NSMutableDictionary *dictSenders;
@end

@implementation picFileSendrMgr
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
        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(clientDisconnect:)
                                                     name:kNotificationClientDisconnect
                                                   object:nil];
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

-(void)didSendFinish:(NSString *)threadName
{
    if (self.dictSenders[threadName]) {
        picFileSender *fs = self.dictSenders[threadName];
        [self.dictSenders removeObjectForKey:threadName];
        
        [fs cancel];
    }
}
@end
