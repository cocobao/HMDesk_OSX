//
//  picTcpLinkObj.m
//  picSimpleSendDeskServer
//
//  Created by admin on 2016/10/13.
//  Copyright © 2016年 ybz. All rights reserved.
//

#import "picTcpLinkObj.h"
#import "picNetComMethod.h"
#import "picLinkObj.h"
#import "GCDMulticastDelegate.h"

@implementation picClient
-(instancetype)init
{
    self = [super init];
    if (self) {
        _mRecvDataBuf = [[NSMutableData alloc] initWithLength:(1024*1024*10)];
        _mArrRecvPack = [NSMutableArray arrayWithCapacity:10];
        
        pSrc = (uint8_t *)_mRecvDataBuf.bytes;
        pSeek = pSrc;
    }
    return self;
}

-(void)addDataToBuf:(NSData *)data
{
    memcpy(pSeek, data.bytes, data.length);
    pSeek += data.length;
}

-(NSInteger)lastDataCount
{
    return (pSeek - pSrc);
}

-(void)sortPack
{
    NSInteger lastLen = [self lastDataCount];
    do {
        if (lastLen < sizeof(stPssProtocolHead)) {
            return;
        }
        
        stPssProtocolHead *head = (stPssProtocolHead *)pSrc;
        if (head->head[0] != HEADER_0 ||
            head->head[1] != HEADER_1 ||
            head->head[2] != HEADER_2 ||
            head->head[3] != HEADER_3 ) {
            //脏数据
            memmove(pSrc, pSrc+1, lastLen-1);
            continue;
        }
        
        int msgLen = ntohl(head->bodyLength);
        if (msgLen < 0 || msgLen > 10*1024*1024) {
            //脏数据
            pSeek = pSrc;
            break;
        }
        
        int packLen = msgLen + sizeof(stPssProtocolHead);
        if (lastLen < packLen) {
            //数据包不完整
            break;
        }
        
        NSData *pack = [[NSData alloc] initWithBytes:pSrc length:packLen];
        lastLen = lastLen-packLen;
        if (lastLen > 0) {
            memmove(pSrc, pSrc+packLen, lastLen);
            pSeek = pSrc + lastLen;
        }else{
            pSeek = pSrc;
        }
        
        head = (stPssProtocolHead *)pack.bytes;
        head->bodyLength = msgLen;
        head->msgId = ntohl(head->msgId);
        head->uid = _uid;
        
        pssHSMmsg *msg = [[pssHSMmsg alloc] initWithData:pack uid:head->uid msgId:head->msgId block:nil];
        [_mArrRecvPack addObject:msg];
    } while (lastLen > 0);
}
@end

@interface picTcpLinkObj ()<GCDAsyncSocketDelegate>
@property (nonatomic, strong) dispatch_queue_t mSocketQueue;
@property (nonatomic, strong) dispatch_queue_t mRecvHandleQueue;
@property (nonatomic, strong) GCDAsyncSocket *gcdSocket;
@property (nonatomic, strong) NSMutableArray *arrClientSockets;
@property (nonatomic, strong) GCDMulticastDelegate <NetTcpCallback> *multicastDelegate;
@property (nonatomic, assign) void *RecvQueueTag;
@property (nonatomic, strong) NSMutableArray *mMessageQueue;
@end

@implementation picTcpLinkObj
__strong static id sharedInstance = nil;
-(instancetype)init
{
    if (self = [super init]) {
        
        _mSocketQueue = dispatch_queue_create("_mSocketQueue", nil);
        _mRecvHandleQueue = dispatch_queue_create("_mRecvHandleQueue", nil);
         dispatch_queue_set_specific(_mRecvHandleQueue, _RecvQueueTag, _RecvQueueTag, NULL);
        _gcdSocket = [[GCDAsyncSocket alloc] initWithDelegate:self delegateQueue:_mSocketQueue socketQueue:_mSocketQueue];
        [_gcdSocket setIPv6Enabled:YES];
        [_gcdSocket setPreferIPv4OverIPv6:NO];
        [_gcdSocket setAutoDisconnectOnClosedReadStream:YES];
        _arrClientSockets = [NSMutableArray array];
        _mMessageQueue = [NSMutableArray arrayWithCapacity:20];
        //消息广播代理
        _multicastDelegate = (GCDMulticastDelegate <NetTcpCallback> *)[[GCDMulticastDelegate alloc] init];
    }
    return self;
}

//等待客户端TCP连接
-(void)serviceAccept
{
    uint16_t port = ACCEPT_PORT;
    NSError *error;
    BOOL ret = [_gcdSocket acceptOnPort:port error:&error];
    if (!ret) {
        NSLog(@"%@", error);
    }
    NSLog(@"accept on local %@:%d", [picNetComMethod localIPAdress], port);
}

//根据用户ID查找对应的IP
-(NSString *)getIpWithUid:(uint32_t)uid
{
    NSPredicate *predicate = [NSPredicate predicateWithFormat:@"SELF.uid = %d", uid];
    NSArray *arr = [_arrClientSockets filteredArrayUsingPredicate:predicate];
    if (arr.count > 0) {
        picClient *client = [arr firstObject];
        return client.addrString;
    }
    return nil;
}

#pragma mark - GCDAsyncSocketDelegate
- (void)socket:(GCDAsyncSocket *)sock didAcceptNewSocket:(GCDAsyncSocket *)newSocket
{
    [_arrClientSockets enumerateObjectsUsingBlock:^(id  _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
        picClient *client = (picClient *)obj;
        if ([client.addrString isEqualToString:newSocket.connectedHost] &&
            client.port == newSocket.connectedPort) {
            client.mSocket = newSocket;
        }
    }];
    [newSocket readDataWithTimeout:-1 tag:100];
}

//有新的客户端接入连接
- (dispatch_queue_t)newSocketQueueForConnectionFromAddress:(NSData *)address onSocket:(GCDAsyncSocket *)sock
{
    NSString *addrString = [GCDAsyncSocket hostFromAddress:address];
    uint16_t port = [GCDAsyncSocket portFromAddress:address];
    NSLog(@"connect from addr:%@:%d", addrString, port);

    //分配一个客户端对象
    picClient *client = [[picClient alloc] init];
    client.addrString = addrString;
    client.port = port;
    client.uid = [pssHSMmsg getRandomMessageID];//分配一个uid
    [_arrClientSockets addObject:client];

    for (int i = 0; i < (int)_arrClientSockets.count-1; i++) {
        picClient *postClient = _arrClientSockets[i];
        if ([postClient.addrString isEqualToString:addrString] &&
            postClient.port == port) {
            [_arrClientSockets removeObjectAtIndex:i];
            break;
        }
    }
    
    return _mSocketQueue;
}

//连接断开
- (void)socketDidDisconnect:(GCDAsyncSocket *)sock withError:(NSError *)err
{
    for (int i = (int)_arrClientSockets.count-1; i>=0; i--) {
        picClient *client = _arrClientSockets[i];
        [_arrClientSockets removeObjectAtIndex:i];
        
        if (client.mSocket.socketFD <= 0) {
            [client.mSocket disconnect];

            NSLog(@"did disconnect, ClientSocket count:%zd", _arrClientSockets.count);
            
            NSNotificationCenter *nofity = [NSNotificationCenter defaultCenter];
            [nofity postNotificationName:kNotificationClientDisconnect object:@{ptl_uid:@(client.uid)}];
        }
    }
}

//接收数据
-(void)socket:(GCDAsyncSocket *)sock didReadData:(NSData *)data withTag:(long)tag
{
    NSPredicate *predicate = [NSPredicate predicateWithBlock:^BOOL(id  _Nullable evaluatedObject, NSDictionary<NSString *,id> * _Nullable bindings) {
        picClient *client = (picClient *)evaluatedObject;
        if (client.mSocket == sock) {
            return YES;
        }
        return NO;
    }];
    
    picClient *client = [[_arrClientSockets filteredArrayUsingPredicate:predicate] firstObject];
    if (client == nil) {
        return;
    }
    
    [client addDataToBuf:data];
    [self didReadDataPack:client];
    [sock readDataWithTimeout:-1 tag:0];
}

#pragma mark - 
//对所有客户端进行消息广播推送
-(void)broadcastPack:(pssHSMmsg *)pack
{
    if (_arrClientSockets.count == 0) {
        return;
    }
    
    for (picClient *client in _arrClientSockets) {
        [client.mSocket writeData:pack.sendData withTimeout:10 tag:0];
        [client.mSocket readDataWithTimeout:-1 tag:0];
    }
}

//发送数据包
-(void)sendPack:(pssHSMmsg *)pack
{
    NSPredicate *predicate = [NSPredicate predicateWithFormat:@"SELF.uid = %d", pack.uid];
    NSArray *arr = [_arrClientSockets filteredArrayUsingPredicate:predicate];
    picClient *client = nil;
    if (arr.count > 0) {
        client = [arr firstObject];
    }
    if (client == nil) {
        return;
    }
    
    if (pack.sendBlock != nil) {
        @synchronized (_mMessageQueue) {
            [_mMessageQueue addObject:pack];
        }
    }
    
    [client.mSocket writeData:pack.sendData withTimeout:10 tag:0];
}

//处理接收数据分包
-(void)didReadDataPack:(picClient *)client
{
    [client sortPack];

    WeakSelf(weakSelf);
    while (client.mArrRecvPack.count > 0) {
        pssHSMmsg *msg = [client.mArrRecvPack firstObject];
        [client.mArrRecvPack removeObjectAtIndex:0];
        
        dispatch_async(dispatch_get_global_queue(0, 0), ^{
            [weakSelf packHandler:client data:msg];
        });
    }
}

//每个分包处理
-(void)packHandler:(picClient *)client data:(pssHSMmsg *)msg
{
    stPssProtocolHead *head = (stPssProtocolHead *)msg.sendData.bytes;
    char *body = (char *)(msg.sendData.bytes + sizeof(stPssProtocolHead));
    
    if (head->type == emPssProtocolType_Login) {
        client.isAuth = YES;
        [picLink NetApi_LoginServiceAck:msg];
    }else{
        if (!client.isAuth) {
            return;
        }
        
        if (head->type == emPssProtocolType_RecvFile){
            int sizeSpace = sizeof(unsigned long long);
            NSData *fileData = [NSData dataWithBytes:body+sizeSpace length:(msg.sendData.length - sizeof(stPssProtocolHead)-sizeSpace)];
            unsigned long long fileId = 0;
            memcpy(&fileId, body, sizeSpace);
            [_multicastDelegate NetRecvFileUid:client.uid fileId:fileId Data:fileData];
            return;
        }
    }

    NSDictionary *dict = nil;
    if (head->bodyLength > 0) {
        NSData *jsonData = [[NSData alloc] initWithBytes:body length:head->bodyLength];
        dict = [utility jsonObjectWithJsonData:jsonData];
    }
    
    if ([dict isKindOfClass:[NSDictionary class]]) {
        msg.body = dict;
    }
    
    NSPredicate *predicate = [NSPredicate predicateWithFormat:@"(SELF.msgId == %d)", head->msgId];
    NSArray *tmpArr = [_mMessageQueue filteredArrayUsingPredicate:predicate];
    if (tmpArr.count > 0) {
        pssHSMmsg *msgSave = nil;
        msgSave = [tmpArr firstObject];
        @synchronized (_mMessageQueue) {
            [_mMessageQueue removeObject:msgSave];
        }
        if (msgSave.sendBlock) {
            msgSave.sendBlock(dict, nil);
        }
    }else{
        //代理回调
        [_multicastDelegate NetTcpCallback:msg error:nil];
    }
}

#pragma mark - GCDMulticastDelegate
- (void)addDelegate:(id)delegate
{
    dispatch_block_t block = ^{
        [_multicastDelegate addDelegate:delegate delegateQueue:_mRecvHandleQueue];
    };
    
    if (dispatch_get_specific(_RecvQueueTag))
        block();
    else
        dispatch_async(_mRecvHandleQueue, block);
}

- (void)removeDelegate:(id)delegate delegateQueue:(dispatch_queue_t)delegateQueue
{
    dispatch_block_t block = ^{
        [_multicastDelegate removeDelegate:delegate delegateQueue:delegateQueue];
    };
    
    if (dispatch_get_specific(_RecvQueueTag))
        block();
    else
        dispatch_sync(_mRecvHandleQueue, block);
}

- (void)removeDelegate:(id)delegate
{
    dispatch_block_t block = ^{
        [_multicastDelegate removeDelegate:delegate];
    };
    
    if (dispatch_get_specific(_RecvQueueTag))
        block();
    else
        dispatch_sync(_mRecvHandleQueue, block);
}
@end
