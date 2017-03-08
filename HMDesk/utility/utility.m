//
//  utility.m
//  picSimpleSendDeskServer
//
//  Created by admin on 2016/10/14.
//  Copyright © 2016年 ybz. All rights reserved.
//

#import "utility.h"
#import <SystemConfiguration/CaptiveNetwork.h>
#import <CommonCrypto/CommonDigest.h>

@implementation utility
+(NSData *)dictionaryToData:(id)dict
{
    if ([NSJSONSerialization isValidJSONObject:dict])
    {
        return [NSJSONSerialization dataWithJSONObject:dict options:NSJSONWritingPrettyPrinted error:nil];
    }
    return nil;
}

+ (id)jsonObjectWithJsonData:(NSData *)jsonData{
    
    NSError *error = nil;
    id jsonObject = [NSJSONSerialization
                     JSONObjectWithData:jsonData
                     options:NSJSONReadingAllowFragments
                     error:&error];
    
    if (jsonObject != nil && error == nil){
        return jsonObject;
    }
    return nil;
}


@end
