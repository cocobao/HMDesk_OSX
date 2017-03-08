//
//  mvThread.h
//  picSimpleSendDeskServer
//
//  Created by admin on 2017/2/4.
//  Copyright © 2017年 ybz. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface mvThread : NSObject
-(void)addMvThread:(uint)uid file:(NSString *)file;
-(void)removeMvThread:(uint)uid;
@end
