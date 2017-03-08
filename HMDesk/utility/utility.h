//
//  utility.h
//  picSimpleSendDeskServer
//
//  Created by admin on 2016/10/14.
//  Copyright © 2016年 ybz. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface utility : NSObject
+(NSData *)dictionaryToData:(id)dict;
+ (id)jsonObjectWithJsonData:(NSData *)jsonData;
@end
