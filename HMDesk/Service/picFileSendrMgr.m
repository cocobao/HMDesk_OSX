//
//  picFileSendrMgr.m
//  HMDesk
//
//  Created by admin on 2017/3/8.
//  Copyright © 2017年 ybz. All rights reserved.
//

#import "picFileSendrMgr.h"
#import "picFileSender.h"

@interface picFileSendrMgr ()
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

-(NSMutableDictionary *)dictSenders
{
    if (!_dictSenders) {
        _dictSenders = [NSMutableDictionary dictionaryWithCapacity:10];
    }
    return _dictSenders;
}

-(void)addSendingFile:(NSString *)filePath
{
    
}
@end
