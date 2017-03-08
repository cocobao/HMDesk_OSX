//
//  picNetComMethod.h
//  picSimpleSendDeskServer
//
//  Created by admin on 2016/10/14.
//  Copyright © 2016年 ybz. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface picNetComMethod : NSObject
+ (NSString *)localIPAdress;
+ (NSString *)inet_ntoa:(unsigned int)addr;
@end
