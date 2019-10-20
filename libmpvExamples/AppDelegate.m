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
    [_currentExample shutdown];
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
    
    dispatch_queue_t q = dispatch_queue_create("com.libmpvExamples.open-file", 0);
    __block NSURL *URL = nil;
    dispatch_sync(q, ^{
        if (openPanel.runModal == NSModalResponseOK) {
            URL = openPanel.URL;
        }
    });

    return URL;
}

- (void)destroyCurrentExample {
    [_currentExample shutdown];
    self.currentExample = nil;
}

- (BOOL)hasFileURL {
    if (!_fileURL) {
        if ((_fileURL = [self selectFile])) {
            _window.representedURL = _fileURL;
        } else {
            NSBeep();
            return NO;
        }
        _window.representedURL = _fileURL;
    }
    
    return YES;
}

#pragma mark - IBAction methods

- (IBAction)runCocoaCBExample:(id)sender {
    
    if (_currentExample) {
        [self destroyCurrentExample];
    }
    
    if (![self hasFileURL]) {
        return;
    }
    
    CocoaCB *ccb = CocoaCB.new;
    const char *args[] = { "loadfile", _fileURL.fileSystemRepresentation, NULL };
    mpv_command(ccb.mpv.mpv_handle, args);
    
    self.currentExample = ccb;
    
}

- (IBAction)runMPVPlayerNSOpenGLViewExample:(id)sender {
    [self runMPVPlayerExample:MPVPlayerExampleNSOpenGLView];
}

- (IBAction)runMPVPlayerNSViewExample:(id)sender {
    [self runMPVPlayerExample:MPVPlayerExampleNSView];
}

- (IBAction)runMPVPlayerHybridViewExample:(id)sender {
    [self runMPVPlayerExample:MPVPlayerExampleHybridView];
}

- (IBAction)runMPVPlayerCAOpenGLLayerExample:(id)sender {
    [self runMPVPlayerExample:MPVPlayerExampleCAOpenGLLayer];
}

- (void)runMPVPlayerExample:(MPVPlayerExampleType)type {
    
    if (_currentExample) {
        [self destroyCurrentExample];
    }
    
    if (![self hasFileURL]) {
        return;
    }
    
    MPVPlayerExample *example = [[MPVPlayerExample alloc] initWithExample:type];

    if (example) {
        self.currentExample = example;
        [example.player openURL:_fileURL];
        [example.player play];

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

- (IBAction)stopExample:(id)sender {
    [self destroyCurrentExample];
}

@end
