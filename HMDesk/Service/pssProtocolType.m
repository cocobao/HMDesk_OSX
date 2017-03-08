//
//  pssProtocolType.m
//  pinut
//
//  Created by admin on 2017/1/19.
//  Copyright © 2017年 ybz. All rights reserved.
//

#import "pssProtocolType.h"

@implementation pssHSMmsg
-(instancetype)initWithData:(NSData *)data uid:(uint)uid msgId:(int)msgId block:(msgSendBlock)block
{
    self = [super init];
    if (self) {
        _sendData = data;
        _msgId = msgId;
        _sendBlock = block;
        _sendTime = time(NULL);
        _recvTime = time(NULL);
        _uid = uid;
    }
    return self;
}

static uint32_t randomMessageId;

+(void)initRandomId
{
    randomMessageId = 1 + arc4random() % 100000;
}

+(uint32_t)getRandomMessageID
{
    @synchronized(self) {
        randomMessageId += 1;
    }
    return randomMessageId;
}
@end
