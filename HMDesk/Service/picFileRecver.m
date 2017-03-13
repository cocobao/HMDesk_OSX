//
//  picFileRecver.m
//  HMDesk
//
//  Created by admin on 2017/3/13.
//  Copyright © 2017年 ybz. All rights reserved.
//

#import "picFileRecver.h"

@interface picFileRecver ()
@property (nonatomic, strong) NSFileHandle *fileHandle;
@end

@implementation picFileRecver
-(instancetype)initWithUid:(NSInteger)uid FileId:(NSInteger)fileId filePath:(NSString *)filePath fileSize:(NSInteger)fileSize
{
    self = [super init];
    if (self) {
        _uid = uid;
        _fileId = fileId;
        _filePath = filePath;
        _fileSize = fileSize;
        _seek = 0;
        _persent = 0;
        _fileHandle = [NSFileHandle fileHandleForUpdatingAtPath:filePath];
    }
    return self;
}

-(void)writeFileData:(NSData *)data
{
    [_fileHandle seekToEndOfFile];
    [_fileHandle writeData:data];
    
    _seek += data.length;
    if (_seek >= _fileSize) {
        _persent = 100;
        [_fileHandle closeFile];
        if (self.m_delegate && [self.m_delegate respondsToSelector:@selector(didRecvFileFinish:fileId:)]) {
            [self.m_delegate didRecvFileFinish:_uid fileId:_fileId];
        }
    }else{
        _persent = ((double)_seek/_fileSize)*100;
    }
}
@end
