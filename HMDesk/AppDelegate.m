//
//  AppDelegate.m
//  HMDesk
//
//  Created by admin on 2017/3/7.
//  Copyright © 2017年 ybz. All rights reserved.
//

#import "AppDelegate.h"
#import "picLinkObj.h"
#include <sys/types.h>
#include <sys/stat.h>
#include <fcntl.h>

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
@end

@implementation AppDelegate

- (void)applicationDidFinishLaunching:(NSNotification *)aNotification {
    // Insert code here to initialize your application
    
    _ipLabel.stringValue = [picNetComMethod localIPAdress];
    
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
    
    
    [picLink addTcpDelegate:self];
    [self readRootPath];
}

- (void)applicationWillTerminate:(NSNotification *)aNotification {
    // Insert code here to tear down your application
}

-(void)openFile:(NSButton *)sender
{
    NSString *path = [_selectFilePath stringValue];
    if(path.length == 0)
        return;

    //读取文件属性
    
    NSData *data = [UPan_FileMng readFile:path];
    
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
    
    if (head->type == emPssProtocolType_OpenFile) {
        
    }else if (head->type == emPssProtocolType_CloseMv){
        
    }else if (head->type == emPssProtocolType_OpenDir){
        
    }
}
@end
