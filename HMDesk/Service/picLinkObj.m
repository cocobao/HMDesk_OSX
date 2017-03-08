//
//  picLinkObj.m
//  picSimpleSendDeskServer
//
//  Created by admin on 2017/1/19.
//  Copyright © 2017年 ybz. All rights reserved.
//

#import "picLinkObj.h"
#import "picNetComMethod.h"

@interface picLinkObj ()<pssUdpLinkDelegate>
@property (nonatomic, strong) picUdpLinkObj *udp_link;
@property (nonatomic, strong) picTcpLinkObj *tcp_link;
@end

@implementation picLinkObj
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
    self = [super init];
    if (self) {
        [pssHSMmsg initRandomId];
        
        _udp_link = [[picUdpLinkObj alloc] init];
        _tcp_link = [[picTcpLinkObj alloc] init];
        [_tcp_link serviceAccept];
        
        _udp_link.m_delegate = self;
    }
    return self;
}

-(void)addTcpDelegate:(id)obj
{
    if (obj == nil) {
        return;
    }
    [_tcp_link addDelegate:obj];
}

-(void)removeTcpDelegate:(id)obj
{
    [_tcp_link removeDelegate:obj];
}

-(pssHSMmsg *)packDataWithId:(int32_t)msgId uid:(uint)uid type:(NSInteger)type body:(NSDictionary *)body block:(msgSendBlock)block
{
    NSData *jsonData = [utility dictionaryToData:body];
    
    NSMutableData *data = [[NSMutableData alloc] initWithLength:(jsonData.length + sizeof(stPssProtocolHead))];
    stPssProtocolHead *head = (stPssProtocolHead *)data.bytes;
    head->head[0] = HEADER_0;
    head->head[1] = HEADER_1;
    head->head[2] = HEADER_2;
    head->head[3] = HEADER_3;
    head->version = 0x1;
    head->msgId = htonl(msgId);
    head->type = type;
    head->uid = uid;
    head->bodyLength = htonl(jsonData.length);
    if (jsonData.length > 0){
        memcpy((void *)(data.bytes + sizeof(stPssProtocolHead)), jsonData.bytes, jsonData.length);
    }
    pssHSMmsg *pack = [[pssHSMmsg alloc] initWithData:data uid:uid msgId:msgId block:block];
    return pack;
}

-(void)setProtocolHead:(NSData *)data type:(NSInteger)type
{
    stPssProtocolHead *protoHead = (stPssProtocolHead *)data.bytes;
    protoHead->head[0] = HEADER_0;
    protoHead->head[1] = HEADER_1;
    protoHead->head[2] = HEADER_2;
    protoHead->head[3] = HEADER_3;
    protoHead->version = 0x1;
    protoHead->msgId = 0;
    protoHead->type = type;
    protoHead->bodyLength = htonl((int)data.length - sizeof(stPssProtocolHead));
}

//广播ip地址
-(void)broadcast
{
    NSString *localIp = [picNetComMethod localIPAdress];
    uint16_t port = htons(ACCEPT_PORT);
    
    NSDictionary *dic = @{@"ip":localIp, @"port":@(port)};
    uint32_t msgId = [pssHSMmsg getRandomMessageID];
    
    pssHSMmsg *pack = [self packDataWithId:msgId uid:0 type:emPssProtocolType_Broadcast body:dic block:nil];
    
    [_udp_link broadcastMyIp:pack];
}

//登陆ack
-(void)NetApi_LoginServiceAck:(pssHSMmsg *)pack
{
    NSLog(@"client login, uid:%d", pack.uid);
    stPssProtocolHead *head = (stPssProtocolHead *)pack.sendData.bytes;
    
    NSDictionary *dict = @{ptl_uid:@(head->uid)};
    pssHSMmsg *newpack = [self packDataWithId:head->msgId uid:head->uid type:head->type body:dict block:nil];
    [_tcp_link sendPack:newpack];
}

//推送当前路径
-(void)PushDir_dirs:(NSArray *)dirs
{
    uint32_t msgId = [pssHSMmsg getRandomMessageID];
    NSDictionary *dict = @{ptl_files:dirs};
    pssHSMmsg *pack = [self packDataWithId:msgId uid:0 type:emPssProtocolType_PushDir body:dict block:nil];
    [_tcp_link broadcastPack:pack];
}

//打开文件ack
-(void)NetApi_OpenFileAck:(pssHSMmsg *)pack
{
    stPssProtocolHead *head = (stPssProtocolHead *)pack.sendData.bytes;
    
    NSDictionary *dict = @{ptl_status:@200};
    pssHSMmsg *newpack = [self packDataWithId:head->msgId uid:head->uid type:head->type body:dict block:nil];
    [_tcp_link sendPack:newpack];
}

//视频文件信息
-(void)NetApi_VideoWithUid:(NSInteger)uid
                      info:(NSDictionary *)info
                 block:(msgSendBlock)block
{
    uint32_t msgId = [pssHSMmsg getRandomMessageID];
    pssHSMmsg *newpack = [self packDataWithId:msgId uid:(uint)uid type:emPssProtocolType_VideoInfo body:info block:block];
    [_tcp_link sendPack:newpack];
}

//请求发送文件
-(void)NetApi_ApplySendFileWithUid:(NSInteger)uid
                              info:(NSDictionary *)info
                             block:(msgSendBlock)block
{
    uint32_t msgId = [pssHSMmsg getRandomMessageID];
    pssHSMmsg *newpack = [self packDataWithId:msgId uid:(uint)uid type:emPssProtocolType_ApplySendFile body:info block:block];
    [_tcp_link sendPack:newpack];
}

//发送视频数据
-(void)sendMvData:(NSData *)data toHost:(NSString *)host
{
    [self setProtocolHead:data type:emPssProtocolType_VideoData];
    [_udp_link sendData:data toHost:host];
}

//发送音频数据
-(void)sendAuData:(NSData *)data toHost:(NSString *)host
{
    [self setProtocolHead:data type:emPssProtocolType_AudioData];
    [_udp_link sendData:data toHost:host];
}

-(NSString *)getIpWithUid:(uint32_t)uid
{
    return [_tcp_link getIpWithUid:uid];
}

-(void)recvBoatcastWithIp:(NSString *)ip
{
    NSDictionary *dic = @{@"hello":@(200)};
    uint32_t msgId = [pssHSMmsg getRandomMessageID];
    
    pssHSMmsg *pack = [self packDataWithId:msgId uid:0 type:emPssProtocolType_Broadcast body:dic block:nil];
    [_udp_link sendData:pack.sendData toHost:ip];
}
@end
