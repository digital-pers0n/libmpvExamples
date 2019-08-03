//
//  AppDelegate.m
//  libmpvExamples
//
//  Created by Terminator on 2019/08/01.
//  Copyright © 2019年 home. All rights reserved.
//

#import "AppDelegate.h"
#import "libmpvExamples.h"

@interface AppDelegate ()

@property (weak) IBOutlet NSWindow *window;
@property NSURL *fileURL;
@property id currentExample;

@end

@implementation AppDelegate

#pragma mark - NSApplicationDelegate

- (void)applicationDidFinishLaunching:(NSNotification *)aNotification {

}

- (void)applicationWillTerminate:(NSNotification *)aNotification {
    _currentExample = nil;
}

- (BOOL)application:(NSApplication *)sender openFile:(NSString *)filename {
    _fileURL = [NSURL fileURLWithPath:filename];
    _window.representedURL = _fileURL;
    return YES;
}

#pragma mark - Methods

- (NSURL *)selectFile {
    NSOpenPanel *openPanel = NSOpenPanel.openPanel;
    openPanel.allowedFileTypes = @[@"mkv", @"mp4", @"avi", @"m4v", @"mov", @"3gp", @"ts", @"mts", @"m2ts", @"wmv", @"flv", @"f4v", @"asf", @"webm", @"rm", @"rmvb", @"qt", @"dv", @"mpg", @"mpeg", @"mxf", @"vob", @"gif"];
    if (openPanel.runModal == NSModalResponseOK) {
        return openPanel.URL;
    }
    return nil;
}

#pragma mark - IBAction methods

- (IBAction)runCocoaCBExample:(id)sender {
    if (_currentExample) {
        _currentExample = nil;
    }
    
    if (!_fileURL) {
        if (!(_fileURL = [self selectFile])) {
            NSBeep();
            return;
        }
    } else {
        _window.representedURL = _fileURL;
        CocoaCB *ccb = CocoaCB.new;
        const char *args[] = { "loadfile", _fileURL.fileSystemRepresentation, NULL };
        mpv_command(ccb.mpv.mpv_handle, args);
        _currentExample = ccb;
    }
}

- (void)openDocument:(id)sender {
    NSURL *filename = [self selectFile];
    if (filename) {
        _fileURL = filename;
        _window.representedURL = filename;
        [NSDocumentController.sharedDocumentController noteNewRecentDocumentURL:filename];
    }
}


@end
