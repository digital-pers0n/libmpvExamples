//
//  MPVClientExample.mm
//  libmpvExamples
//
//  Created by Terminator on 2021/6/22.
//  Copyright © 2021年 home. All rights reserved.
//

#import "MPVClientExample.h"
#import "MPVClient.h"
#import "MPVVideoRenderer.h"

#ifndef MPV_CLIENT_EXAMPLE_USE_LEGACY_HWDEC
#define MPV_CLIENT_EXAMPLE_USE_LEGACY_HWDEC 0
#endif

@implementation MPVClientExample {
    MPVClient *_mpv;
}

- (instancetype)initWithExampleName:(NSString *)str {
    if (!(self = [super init])) return nil;
    
    auto cls = NSClassFromString(str);
    NSAssert(cls, @"Failed to load class for '%@'", str);
    _mpv = [[MPVClient alloc] initWithBlock:^(MPVClient *mpv){
#if MPV_CLIENT_EXAMPLE_USE_LEGACY_HWDEC
        [mpv setString:@"uyvy422" forName:@"hwdec-image-format"];
#endif
        [mpv setBool:NO forName:@"ytdl"];
        [mpv setBool:NO forName:@"load-stats-overlay"];
        [mpv setBool:NO forName:@"load-scripts"];
        [mpv setBool:NO forName:@"load-osd-console"];
    }];
    NSView<MPVVideoRenderer> *ex = [[cls alloc] initWithFrame:{} client:_mpv];
    NSAssert(ex, @"Failed to create example for '%@'", cls);
    
    const auto mask = NSWindowStyleMaskTitled  | NSWindowStyleMaskClosable  |
               NSWindowStyleMaskMiniaturizable | NSWindowStyleMaskResizable;
    
    auto win = [[NSWindow alloc] initWithContentRect:{{}, {1280, 720}}
                                styleMask:mask backing:NSBackingStoreBuffered
                                    defer:YES screen:[NSScreen mainScreen]];
    win.releasedWhenClosed = NO;
    win.movableByWindowBackground = YES;
    win.contentView = ex;
    _window = win;
    auto nc = [NSNotificationCenter defaultCenter];
    [nc addObserver:self selector:@selector(willClose:)
               name:NSWindowWillCloseNotification object:win];
    [nc addObserver:self selector:@selector(willClose:)
               name:MPVClientWillShutdownNotification object:_mpv];
    win.title = str;
    [win makeKeyAndOrderFront:nil];
    [win center];
    
    return self;
}

- (id<MPVPlayer>)player {
    return _mpv;
}

- (void)shutdown {
    [_window performClose:nil];
}

- (void)willClose:(NSNotification*)n {
    [NSNotificationCenter.defaultCenter removeObserver:self];
    id<MPVVideoRenderer> view = _window.contentView;
    [view destroy];
}

@end
