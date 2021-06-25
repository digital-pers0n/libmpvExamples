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
#import "MPVExampleProtocol.h"

@interface MPVExampleInfo : NSObject

@property (nonatomic) NSString * name;
@property (nonatomic) NSString * groupName;
@property (nonatomic) NSString * info;

@end

@implementation MPVExampleInfo {
    Class _groupClass;
}

+ (instancetype)exampleWithName:(NSString *)name group:(NSString *)groupName
                           info:(NSString *)info {
    return [[MPVExampleInfo alloc] initWithName:name group:groupName info:info];
}

- (instancetype)initWithName:(NSString *)name group:(NSString *)groupName
                        info:(NSString *)info {
    if (!(self = [super init])) return nil;
    _name = name;
    _groupName = groupName;
    _info = info;
    return self;
}

- (id<MPVExample>)build {
    if (!_groupClass) {
        Class group = NSClassFromString(_groupName);
        NSAssert(group, @"%@ is unknown group name.", _groupName);
        NSAssert([group conformsToProtocol:@protocol(MPVExample)],
                 @"%@ doesn't conform to %@", group, @protocol(MPVExample));
        _groupClass = group;
    }
    return [[_groupClass alloc] initWithExampleName:_name];
}

@end

@interface AppDelegate ()

@property (assign) IBOutlet NSWindow *window;
@property (assign) IBOutlet NSArrayController *examplesController;
@property NSURL *fileURL;
@property id currentExample;

@end

@implementation AppDelegate

#pragma mark - NSApplicationDelegate

- (void)applicationDidFinishLaunching:(NSNotification *)aNotification {
    
    if (NSAppKitVersionNumber > NSAppKitVersionNumber10_12) {
        NSWindow.allowsAutomaticWindowTabbing = NO;
    }
    
    NSURL * url = [[NSBundle mainBundle] URLForResource:@"MPVExampleInfo" withExtension:@"plist"];
    NSAssert(url, @"Cannot find resources.");
    
#if MAC_OS_X_VERSION_MIN_REQUIRED < MAC_OS_X_VERSION_10_13
    NSDictionary * dict = [NSDictionary dictionaryWithContentsOfURL:url];
    NSAssert(dict, @"Cannot load resources.");
#else
    NSError *err = nil;
    NSDictionary *dict = [NSDictionary dictionaryWithContentsOfURL:url error:&err];
    NSAssert(dict, @"%@", err);
#endif
    
    NSMutableArray * examples = [NSMutableArray new];
    [dict enumerateKeysAndObjectsUsingBlock:
     ^(NSString *_Nonnull key, NSArray *_Nonnull obj, BOOL * _Nonnull _) {
         for (NSDictionary *d in obj) {
             [examples addObject:[MPVExampleInfo exampleWithName:d[@"name"]
                                                  group:key info:d[@"info"]]];
         }
    }];
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

#pragma mark - NSWindow Notifications

- (void)windowWillClose:(NSNotification *)n {
    NSNotificationCenter * nc = [NSNotificationCenter defaultCenter];
    [nc removeObserver:self
                  name:NSWindowWillCloseNotification
                object:[_currentExample window]];
    self.currentExample = nil;
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

- (void)runExample:(MPVExampleInfo *)info {
    if (_currentExample) {
        [self destroyCurrentExample];
    }
    
    if (![self hasFileURL]) {
        return;
    }
    
    id<MPVExample> ex = [info build];
    [ex.player loadURL:_fileURL];
    NSWindow *window = ex.window;
    self.currentExample = ex;
    
    NSNotificationCenter * nc = [NSNotificationCenter defaultCenter];
    [nc addObserver:self
           selector:@selector(windowWillClose:)
               name:NSWindowWillCloseNotification
             object:window];
}

#pragma mark - IBAction methods

- (IBAction)tableViewDoubleClick:(id)sender {
    MPVExampleInfo * info = _examplesController.selectedObjects.firstObject;
    [self runExample:info];
}

- (IBAction)tableCellViewButtonAction:(NSButton *)sender {
    NSTableCellView * tcv = (NSTableCellView *)[sender superview];
    NSAssert([tcv isKindOfClass:[NSTableCellView class]],
             @"Invalid class %@", [tcv class]);
    MPVExampleInfo * info = tcv.objectValue;
    [self runExample:info];
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
