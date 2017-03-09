//
//  picFileSendrMgr.h
//  HMDesk
//
//  Created by admin on 2017/3/8.
//  Copyright © 2017年 ybz. All rights reserved.
//

#import <Foundation/Foundation.h>

#define FileSendrMgr [picFileSendrMgr shareInstance]

@interface picFileSendrMgr : NSObject
+ (id)shareInstance;
-(void)addSendingUid:(NSInteger)uid filePath:(NSString *)filePath fileId:(NSInteger)fileId;
@end
