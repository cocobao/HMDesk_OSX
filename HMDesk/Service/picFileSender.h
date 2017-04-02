//
//  picFileSender.h
//  HMDesk
//
//  Created by admin on 2017/3/8.
//  Copyright © 2017年 ybz. All rights reserved.
//

#import <Foundation/Foundation.h>

@protocol picFileSenderDelegate <NSObject>
-(void)didSendFinish:(NSString *)threadName;
@end

@interface picFileSender : NSObject
@property (nonatomic, assign) NSInteger mUid;
@property (nonatomic, strong) NSString *threadName;
@property (nonatomic, weak) id<picFileSenderDelegate> m_delegate;

-(instancetype)initWithUid:(NSInteger)uid
                  filePath:(NSString *)filePath
                    fileId:(NSInteger)fileId;
-(void)cancel;

+(NSData *)readFilePartWithPath:(NSString *)filePath apFileId:(NSInteger)apFileId seek:(NSInteger)seek;
@end
