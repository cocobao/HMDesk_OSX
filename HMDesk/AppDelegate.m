//
//  AppDelegate.m
//  HMDesk
//
//  Created by admin on 2017/3/7.
//  Copyright © 2017年 ybz. All rights reserved.
//

#import "AppDelegate.h"
#import "picLinkObj.h"
#import "picFileSendrMgr.h"

@interface AppDelegate ()
@property (weak) IBOutlet NSWindow *window;
@property (nonatomic, weak) IBOutlet NSButton *broadcastBtn;
@property (nonatomic, weak) IBOutlet NSTextField *ipLabel;
@property (nonatomic, weak) IBOutlet NSButton *rootPathBtn;
@property (nonatomic, weak) IBOutlet NSTextField *rootPath;
@property (nonatomic, weak) IBOutlet NSButton *saveRootPathBtn;
@property (nonatomic, weak) IBOutlet NSButton *selectFileBtn;
@property (nonatomic, weak) IBOutlet NSTextField *selectFilePath;
@property (nonatomic, weak) IBOutlet NSButton *sendSelectFileBtn;
@property (nonatomic, weak) IBOutlet NSButton *showInFinder_rootPath;
@property (nonatomic, weak) IBOutlet NSButton *showInFinder_selectFile;
@end

@implementation AppDelegate

- (void)applicationDidFinishLaunching:(NSNotification *)aNotification {
    [_broadcastBtn setTarget:self];
    [_broadcastBtn setAction:@selector(broadcastAction:)];
    
    [_rootPathBtn setTarget:self];
    [_rootPathBtn setAction:@selector(setRootPathAction:)];
    
    [_saveRootPathBtn setTarget:self];
    [_saveRootPathBtn setAction:@selector(saveRootPath:)];
    
    [_sendSelectFileBtn setTarget:self];
    [_sendSelectFileBtn setAction:@selector(openFile:)];
    
    [_selectFileBtn setTarget:self];
    [_selectFileBtn setAction:@selector(selectFileAction:)];
    
    _showInFinder_rootPath.tag = 1;
    [_showInFinder_rootPath setTarget:self];
    [_showInFinder_rootPath setAction:@selector(showInFinder:)];
    
    _showInFinder_selectFile.tag = 2;
    [_showInFinder_selectFile setTarget:self];
    [_showInFinder_selectFile setAction:@selector(showInFinder:)];
    
    _ipLabel.stringValue = [picNetComMethod localIPAdress];
    
    [picLink addTcpDelegate:self];
    [self readRootPath];
}

- (void)applicationWillTerminate:(NSNotification *)aNotification {
    // Insert code here to tear down your application
}

-(void)showInFinder:(NSButton *)sender
{
    NSString *path = nil;
    if (sender.tag == 1) {
        path = [_rootPath stringValue];
    }else{
        path = [_selectFilePath stringValue];
    }
    if (!path) {
        return;
    }
    [[NSWorkspace sharedWorkspace] selectFile:path inFileViewerRootedAtPath:path];
}

-(void)openFile:(NSButton *)sender
{
    NSString *path = [_selectFilePath stringValue];
    if(path.length == 0)
        return;
    
    //读取文件属性
    NSDictionary *info = [UPan_FileMng fileAttriutes:path];
    NSString *fileName = [UPan_FileMng fileNameByPath:path];
    NSDictionary *fileInfo = @{
                               ptl_fileName:fileName,
                               ptl_fileSize:info[NSFileSize],
                               ptl_filePath:path,
                               };
    
    [picLink NetApi_ApplySendFileWithInfo:fileInfo];
}

//广播自己ip地址
-(void)broadcastAction:(NSButton *)sender
{
    [picLink broadcast];
}

-(void)saveRootPath:(NSButton *)sender
{
    NSString *str = [_rootPath stringValue];
    if(str.length == 0)
        return;
    
    NSUserDefaults *ud = [NSUserDefaults standardUserDefaults];
    [ud setValue:str forKey:ptl_rootPath];
    [ud synchronize];
}

-(void)readRootPath
{
    NSUserDefaults *ud = [NSUserDefaults standardUserDefaults];
    id p = [ud objectForKey:ptl_rootPath];
    if (p) {
        [_rootPath setStringValue:p];
    }
}

-(void)setRootPathAction:(NSButton *)sender
{
    NSOpenPanel *panel = [NSOpenPanel openPanel];
    //设置默认的路径
    //    [panel setDirectoryURL:[NSURL URLWithString:NSHomeDirectory()]];
    //设置不允许多选
    [panel setAllowsMultipleSelection:NO];
    //设置可以打开文件夹
    [panel setCanChooseDirectories:YES];
    //设置可以选中文件
    [panel setCanChooseFiles:NO];
    //设置可以打开的文件类型
    //    [panel setAllowedFileTypes:@[@"onecodego"]];
    [panel setAllowsOtherFileTypes:YES];
    
    WeakSelf(weakSelf);
    [panel beginWithCompletionHandler:^(NSInteger result) {
        if (result == NSModalResponseOK) {
            NSURL* elemnet = [[panel URLs] firstObject];
            [weakSelf.rootPath setStringValue:[elemnet path]];
        }
    }];
}

-(void)selectFileAction:(NSButton *)sender
{
    NSOpenPanel *panel = [NSOpenPanel openPanel];
    //设置默认的路径
    //    [panel setDirectoryURL:[NSURL URLWithString:NSHomeDirectory()]];
    //设置不允许多选
    [panel setAllowsMultipleSelection:NO];
    //设置可以打开文件夹
    [panel setCanChooseDirectories:YES];
    //设置可以选中文件
    [panel setCanChooseFiles:YES];
    [panel setCanChooseDirectories:NO];
    //设置可以打开的文件类型
    //    [panel setAllowedFileTypes:@[@"onecodego"]];
    [panel setAllowsOtherFileTypes:YES];
    
    WeakSelf(weakSelf);
    [panel beginWithCompletionHandler:^(NSInteger result) {
        if (result == NSModalResponseOK) {
            NSURL* elemnet = [[panel URLs] firstObject];
            [weakSelf.selectFilePath setStringValue:[elemnet path]];
        }
    }];
}

- (void)NetTcpCallback:(pssHSMmsg *)receData error:(NSError *)error
{
    if (error) {
        NSLog(@"net call error:%@", error);
        return;
    }
    
    stPssProtocolHead *head = (stPssProtocolHead *)receData.sendData.bytes;
    
    if (head->type == emPssProtocolType_ApplySendFile) {
        NSInteger code = [receData.body[ptl_status] integerValue];
        if (code != 200) {
            return;
        }
        NSString *filePath = receData.body[ptl_filePath];
        NSInteger fileId = [receData.body[ptl_fileId] integerValue];
        [FileSendrMgr addSendingUid:head->uid filePath:filePath fileId:fileId];
    }
}
@end
