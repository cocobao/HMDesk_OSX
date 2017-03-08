//
//  UPan_FileMng.m
//  pcKan
//
//  Created by admin on 2017/3/3.
//  Copyright © 2017年 ybz. All rights reserved.
//

#import "UPan_FileMng.h"

@implementation UPan_FileMng
+(NSString *)dirDocument
{
    return [NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES) firstObject];
}

+(NSString *)dirHome{
    return NSHomeDirectory();
}

//获取Library目录
+(NSString *)dirLib{
    return [NSSearchPathForDirectoriesInDomains(NSLibraryDirectory, NSUserDomainMask, YES) firstObject];
}

//获取Cache目录
+(NSString *)dirCache{
    return [NSSearchPathForDirectoriesInDomains(NSCachesDirectory, NSUserDomainMask, YES) firstObject];
}

//获取Tmp目录
+(NSString *)dirTmp{
    return NSTemporaryDirectory();
}

//获取目录下的内容
+(NSArray *)ContentOfPath:(NSString *)path
{
    path = [path stringByStandardizingPath];
    return [[NSFileManager defaultManager] contentsOfDirectoryAtPath:path error:nil];
}

+(NSArray *)DocumentPathSource
{
    return [UPan_FileMng ContentOfPath:[UPan_FileMng dirDocument]];
}

+(NSArray *)CachePathSource
{
    return [UPan_FileMng ContentOfPath:[UPan_FileMng dirCache]];
}

//文件属性
+(NSDictionary *)fileAttriutes:(NSString *)file
{
    return [[NSFileManager defaultManager] attributesOfItemAtPath:file error:nil];
}

//创建目录
+(BOOL)createDir:(NSString *)path
{
    if ([[NSFileManager defaultManager] fileExistsAtPath:path]){
        return YES;
    }
    BOOL res=[[NSFileManager defaultManager] createDirectoryAtPath:path withIntermediateDirectories:YES attributes:nil error:nil];
    if (res) {
        NSLog(@"文件夹创建成功");
        return YES;
    }else
        NSLog(@"文件夹创建失败");
    return NO;
}

//创建文件
+(void)createFile:(NSString *)path
{
    if ([[NSFileManager defaultManager] fileExistsAtPath:path]){
        [UPan_FileMng deleteFile:path];
    }
    
    NSFileManager *fileManager = [NSFileManager defaultManager];
    [fileManager createFileAtPath:path contents:nil attributes:nil];
}

//删除文件
+(void)deleteFile:(NSString *)path
{
    NSFileManager *fileManager = [NSFileManager defaultManager];
    [fileManager removeItemAtPath:path error:nil];
}

//读文件数据
+(NSData *)readFile:(NSString *)path
{
    if (![[NSFileManager defaultManager] fileExistsAtPath:path]){
        return nil;
    }
    NSFileManager *fileManager = [NSFileManager defaultManager];
    return [fileManager contentsAtPath:path];
}

//写数据到文件
+(void)writeFile:(NSString *)path data:(NSData *)data
{
    [data writeToFile:path atomically:YES];
}

//根据路径提取文件名称
+(NSString *)fileNameByPath:(NSString *)path
{
    if (!path) {
        return nil;
    }
    NSFileManager *fileManager = [NSFileManager defaultManager];
    return [fileManager displayNameAtPath:path];
}
@end
