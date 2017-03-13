//
//  picLinkObj.h
//  picSimpleSendDeskServer
//
//  Created by admin on 2017/1/19.
//  Copyright © 2017年 ybz. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "picUdpLinkObj.h"
#import "picTcpLinkObj.h"

#define picLink [picLinkObj shareInstance]

@interface picLinkObj : NSObject
+ (id)shareInstance;
-(void)broadcast;
-(void)PushDir_dirs:(NSArray *)dirs;
-(void)NetApi_LoginServiceAck:(pssHSMmsg *)pack;
-(void)NetApi_OpenFileAck:(pssHSMmsg *)pack;

-(void)NetApi_VideoWithUid:(NSInteger)uid
                      info:(NSDictionary *)info
                     block:(msgSendBlock)block;

-(void)NetApi_ApplySendFileWithInfo:(NSDictionary *)info;
-(void)NetApi_ApplyRecvFileAckWithUid:(NSInteger)uid msgId:(uint32_t)msgId fileId:(NSInteger)fileId;
//失败返回
-(void)NetApi_FailAckWithUid:(NSInteger)uid msgId:(uint32_t)msgId type:(NSInteger)type errCode:(NSInteger)errCode msg:(NSString *)msg;

-(NSString *)getIpWithUid:(uint32_t)uid;

-(void)sendMvData:(NSData *)data toHost:(NSString *)host;
-(void)sendAuData:(NSData *)data toHost:(NSString *)host;
-(void)sendFileData:(NSData *)data uid:(int)uid;

-(void)addTcpDelegate:(id)obj;
-(void)removeTcpDelegate:(id)obj;
@end
