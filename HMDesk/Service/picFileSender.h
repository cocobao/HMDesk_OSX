//
//  picFileSender.h
//  HMDesk
//
//  Created by admin on 2017/3/8.
//  Copyright © 2017年 ybz. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface picFileSender : NSObject
@property (nonatomic, strong) NSString *threadName;

-(instancetype)initWithUid:(NSInteger)uid
                  filePath:(NSString *)filePath
                    fileId:(NSInteger)fileId;
@end
