//
//  picTcpLinkObj.h
//  picSimpleSendDeskServer
//
//  Created by admin on 2016/10/13.
//  Copyright © 2016年 ybz. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "GCDAsyncSocket.h"
#import "pssProtocolType.h"

#define ACCEPT_PORT 39890

@protocol NetTcpCallback
@optional
- (void)NetTcpCallback:(pssHSMmsg *)receData error:(NSError *)error;
- (void)NetRecvFileUid:(NSInteger)uid fileId:(unsigned long long)fileId Data:(NSData *)data;
@end

@interface picClient : NSObject
{
    uint8_t *pSrc;
    uint8_t *pSeek;
}
@property (nonatomic, strong) GCDAsyncSocket *mSocket;
@property (nonatomic, copy) NSString *addrString;
@property (nonatomic, assign) uint16_t port;
@property (nonatomic, assign) uint32_t uid;
@property (nonatomic, assign) BOOL isAuth;
@property (nonatomic, strong) NSMutableArray *mArrRecvPack;
@property (nonatomic, strong) NSMutableData *mRecvDataBuf;
-(void)sortPack;
-(void)addDataToBuf:(NSData *)data;
@end

@interface picTcpLinkObj : NSObject

-(void)serviceAccept;
-(void)broadcastPack:(pssHSMmsg *)pack;
-(void)sendPack:(pssHSMmsg *)pack;
-(NSString *)getIpWithUid:(uint32_t)uid;
- (void)addDelegate:(id)delegate;
- (void)removeDelegate:(id)delegate;
-(picClient *)getClient:(uint)uid;
@end


