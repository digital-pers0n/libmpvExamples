//
//  AppDelegate.m
//  libmpvExamples
//
//  Created by Terminator on 2019/08/01.
//  Copyright © 2019年 home. All rights reserved.
//

#import "AppDelegate.h"
#import "libmpvExamples.h"

#import "MPVExample.h"

@interface MPVExampleInfo : NSObject

+ (instancetype)exampleWithName:(NSString *)name
                           info:(NSString *)info
                            tag:(NSInteger)tag;

- (instancetype)initWith:(NSString *)name
                    info:(NSString *)info
                     tag:(NSInteger)tag;

@property (nonatomic) NSString * name;
@property (nonatomic) NSString * info;
@property (nonatomic) NSInteger tag;

@end

@implementation MPVExampleInfo

+ (instancetype)exampleWithName:(NSString *)name
                           info:(NSString *)info
                            tag:(NSInteger)tag
{
    return [[MPVExampleInfo alloc] initWith:name info:info tag:tag];
}

- (instancetype)initWith:(NSString *)name
                    info:(NSString *)info
                     tag:(NSInteger)tag
{
    self = [super init];
    if (self) {
        _name = name;
        _info = info;
        _tag = tag;
    }
    return self;
}
@end

@interface AppDelegate ()

@property (weak) IBOutlet NSWindow *window;
@property (weak) IBOutlet NSArrayController *examplesController;
@property NSURL *fileURL;
@property id currentExample;

@end

@implementation AppDelegate

#pragma mark - NSApplicationDelegate

- (void)applicationDidFinishLaunching:(NSNotification *)aNotification {
    
    NSURL * url = [[NSBundle mainBundle] URLForResource:@"MPVExampleInfo" withExtension:@"plist"];
    NSAssert(url, @"Cannot find resources.");
    
    NSDictionary * dict = [NSDictionary dictionaryWithContentsOfURL:url];
    NSAssert(dict, @"Cannot load resources.");
    
    NSMutableArray * examples = [NSMutableArray new];
    NSArray * objects = dict[@"examples"];
    
    for (NSDictionary * d in objects) {
        [examples addObject:[MPVExampleInfo exampleWithName:d[@"name"]
                                                       info:d[@"info"]
                                                        tag:0]];
    }
    
    [examples addObject:[MPVExampleInfo exampleWithName:@"CocoaCB"
                                                   info:@"CAOpenGLLayer example."
                                                        "Based on CocoaCB from mpv 0.29"
                                                    tag:1]];
    [_examplesController addObjects:examples];
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
    NSURL *URL = nil;

    NSOpenPanel *openPanel = NSOpenPanel.openPanel;
    openPanel.allowedFileTypes = @[@"mkv", @"mp4", @"avi", @"m4v", @"mov", @"3gp", @"ts", @"mts", @"m2ts", @"wmv", @"flv", @"f4v", @"asf", @"webm", @"rm", @"rmvb", @"qt", @"dv", @"mpg", @"mpeg", @"mxf", @"vob", @"gif"];
    
    if (openPanel.runModal == NSModalResponseOK) {
        URL = openPanel.URL;
    }
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

- (IBAction)runExample:(id)sender {
    if (_currentExample) {
        [self destroyCurrentExample];
    }
    
    if (![self hasFileURL]) {
        return;
    }
    MPVExampleInfo * info = _examplesController.selectedObjects.firstObject;
    if (info.tag == 0) {
        MPVExample * example = [[MPVExample alloc] initWithExampleName:info.name];
        [example.player openURL:_fileURL];
        [example.player play];
        self.currentExample = example;
    } else {
        CocoaCB *ccb = [CocoaCB new];
        const char *args[] = { "loadfile", _fileURL.fileSystemRepresentation, NULL };
        mpv_command(ccb.mpv.mpv_handle, args);
        self.currentExample = ccb;
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
