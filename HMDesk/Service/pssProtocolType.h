//
//  pssProtocolType.h
//  pinut
//
//  Created by admin on 2017/1/19.
//  Copyright © 2017年 ybz. All rights reserved.
//

#import <Foundation/Foundation.h>

#define HEADER_0 9
#define HEADER_1 5
#define HEADER_2 2
#define HEADER_3 7

typedef enum {
    emPssCmd_FlashDir,  //更新路径
}emPssCmd;

typedef enum {
    emPssProtocolType_Broadcast,
    emPssProtocolType_Login,
    emPssProtocolType_PushDir, //推送
    emPssProtocolType_OpenFile,
    emPssProtocolType_OpenDir,
    emPssProtocolType_CloseMv,
    emPssProtocolType_VideoInfo,
    emPssProtocolType_ApplySendFile,
    emPssProtocolType_SendFile,
    emPssProtocolType_VideoData = 100,
    emPssProtocolType_AudioData,
}emPssProtocolType;

#pragma pack(1)
typedef struct {
    char head[4];
    char version;
    char type;
    char extend;
    uint uid;
    int msgId;
    int bodyLength;
}stPssProtocolHead;
#pragma pack()

typedef void (^msgSendBlock)(NSDictionary *message, NSError *error);

@interface pssHSMmsg : NSObject
@property (nonatomic, assign) uint uid;
@property (nonatomic, assign) int msgId;
@property (nonatomic, strong) msgSendBlock sendBlock;
@property (nonatomic, strong) NSData *sendData;
@property (nonatomic, assign) time_t sendTime;
@property (nonatomic, assign) time_t recvTime;
@property (nonatomic, copy) NSDictionary *body;

-(instancetype)initWithData:(NSData *)data uid:(uint)uid msgId:(int)msgId block:(msgSendBlock)block;

+(void)initRandomId;
+(uint32_t)getRandomMessageID;
@end
