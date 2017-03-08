//
//  picUdpLinkObj.m
//  picSimpleSendDeskServer
//
//  Created by admin on 2016/10/14.
//  Copyright © 2016年 ybz. All rights reserved.
//

#import "picUdpLinkObj.h"
#import "picNetComMethod.h"
#import "picTcpLinkObj.h"
#import "utility.h"
#include <sys/types.h>
#include <sys/socket.h>
#include <netinet/in.h>
#include <arpa/inet.h>

@interface picUdpLinkObj ()
{
    int mUdpSocket;
    BOOL isRun;
}
@property (nonatomic, strong) dispatch_queue_t mSocketQueue;
@property (nonatomic, strong) NSThread *mThread;
@end

@implementation picUdpLinkObj
-(instancetype)init
{
    if (self = [super init]) {
        _mSocketQueue = dispatch_queue_create("mSocketQueue", nil);

        mUdpSocket = socket(AF_INET, SOCK_DGRAM, 0);
        int nb = 0;
        const int opt = 1;
        const int buf_size = 1024*1024;
        nb = setsockopt(mUdpSocket, SOL_SOCKET, SO_BROADCAST, (char *)&opt, sizeof(opt));
        nb = setsockopt(mUdpSocket, SOL_SOCKET, SO_RCVBUF, (char *)&buf_size, sizeof(buf_size));
        nb = setsockopt(mUdpSocket, SOL_SOCKET, SO_SNDBUF, (char *)&buf_size, sizeof(buf_size));
        
        struct sockaddr_in addrto;
        bzero(&addrto, sizeof(struct sockaddr_in));
        addrto.sin_family = AF_INET;
        addrto.sin_addr.s_addr = htonl(INADDR_ANY);
        addrto.sin_port = htons(BIND_UDP_PORT);
    
        bind(mUdpSocket,(struct sockaddr *)&(addrto), sizeof(struct sockaddr_in));
        
        isRun = YES;
        _mThread = [[NSThread alloc] initWithTarget:self selector:@selector(recvThread) object:nil];
        [_mThread setName:@"udpRecvThread"];
        [_mThread start];
    }
    return self;
}

-(void)recvThread
{
    struct sockaddr_in from;
    int len = sizeof(struct sockaddr_in);
    ssize_t ret= 0;
    uint8_t *pBuf = (uint8_t *)malloc(BUF_SIZE);
    
    while (isRun) {
        ret = recvfrom(mUdpSocket, pBuf, BUF_SIZE, 0, (struct sockaddr*)&from, (socklen_t*)&len);
        if (ret > 0) {
            [self recvHandle:pBuf len:ret from:&from];
        }
    }
    free(pBuf);
}

-(void)recvHandle:(uint8_t *)data len:(NSInteger)len from:(struct sockaddr_in*)from
{
    NSString *addr = [picNetComMethod inet_ntoa:from->sin_addr.s_addr];
    if (!addr) {
        return;
    }
    NSData *ndata = [NSData dataWithBytes:data length:len];
    NSDictionary *dict = [utility jsonObjectWithJsonData:ndata];
    if (dict[@"hello"]) {
        NSString *h = dict[@"hello"];
        if ([h isEqualToString:@"mosimosi"]) {
            if (self.m_delegate && [self.m_delegate respondsToSelector:@selector(recvBoatcastWithIp:)]) {
                [self.m_delegate recvBoatcastWithIp:addr];
            }
        }
    }
}

-(void)broadcastMyIp:(pssHSMmsg *)data
{
    [self sendData:data.sendData toHost:BROUADCAST_IP];
    NSLog(@"broadcast ip:%@:%d", BROUADCAST_IP,BROUADCAST_PORT);
}

-(void)sendData:(NSData *)data toHost:(NSString *)host
{
    struct sockaddr_in addr;
    addr.sin_family = AF_INET;
    addr.sin_port = htons(BROUADCAST_PORT);
    addr.sin_addr.s_addr = inet_addr([host UTF8String]);
    
    ssize_t ret = sendto(mUdpSocket, data.bytes, data.length, 0, (struct sockaddr *)&addr, sizeof(struct sockaddr));
    if (ret < 0) {
        NSLog(@"send size:%zd, length:%zd, %s", ret, data.length, strerror(errno));
    }
}

-(void)sendData:(uint8_t *)data length:(NSInteger)length toHost:(NSString *)host
{
    struct sockaddr_in addr;
    addr.sin_family = AF_INET;
    addr.sin_port = htons(BROUADCAST_PORT);
    addr.sin_addr.s_addr = inet_addr([host UTF8String]);
    
    ssize_t ret = sendto(mUdpSocket, data, length, 0, (struct sockaddr *)&addr, sizeof(struct sockaddr));
    if (ret < 0) {
        NSLog(@"send size:%zd, length:%zd, %s", ret, length, strerror(errno));
    }
}

@end
