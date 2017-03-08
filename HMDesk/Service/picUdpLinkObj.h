//
//  picUdpLinkObj.h
//  picSimpleSendDeskServer
//
//  Created by admin on 2016/10/14.
//  Copyright © 2016年 ybz. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "pssProtocolType.h"

#define BROUADCAST_IP @"255.255.255.255"
#define BROUADCAST_PORT 39891
#define BIND_UDP_PORT 39892
#define BUF_SIZE (1024*1024)

@protocol pssUdpLinkDelegate <NSObject>
@optional
-(void)recvBoatcastWithIp:(NSString *)ip;
@end

@interface picUdpLinkObj : NSObject
@property (nonatomic, weak) id<pssUdpLinkDelegate> m_delegate;
-(void)broadcastMyIp:(pssHSMmsg *)data;
-(void)sendData:(NSData *)data toHost:(NSString *)host;
-(void)sendData:(uint8_t *)data length:(NSInteger)length toHost:(NSString *)host;
@end
