//
//  MPVExample.m
//  libmpvExamples
//
//  Created by Terminator on 2020/05/09.
//  Copyright © 2020年 home. All rights reserved.
//

#import "MPVExample.h"
#import "MPVExampleProtocol.h"
#import "MPVEventView.h"
#import "MPVPlayer.h"

static const NSRect kMPVExampleDefaultFrame =
{
    .origin.x = 0,
    .origin.y = 0,
    .size.width = 1280,
    .size.height = 720
};

@interface MPVExample () {
    NSWindow * _window;
    id <MPVExampleProtocol> _example;
}

@end

@implementation MPVExample

- (instancetype)initWithExampleName:(NSString *)name {
    self = [super init];
    if (self) {
        Class cls = NSClassFromString(name);
        NSAssert(cls, @"Invalid example name.");
        _window = [self createWindow];
        _example = [self createExample:cls];
        if ([_example isKindOfClass:[NSView class]]) {
             _window.contentView = (NSView *)_example;
        } else {
            _window.contentView.layer = (CALayer *)_example;
            _window.contentView.wantsLayer = YES;
        }
        _player = _example.player;
        [self setUpNotifications];
        [_window.contentView addSubview:[self createEventView]];
        _window.title = name;
        [_window makeKeyAndOrderFront:nil];
        [_window center];
        
    }
    return self;
}

- (NSWindow *)createWindow {
    const NSWindowStyleMask mask =
    NSWindowStyleMaskTitled         | NSWindowStyleMaskClosable |
    NSWindowStyleMaskMiniaturizable | NSWindowStyleMaskResizable;
    
    const NSRect frame = kMPVExampleDefaultFrame;
    
    NSWindow * win = [[NSWindow alloc] initWithContentRect:frame
                                                 styleMask:mask
                                                   backing:NSBackingStoreBuffered
                                                     defer:YES
                                                    screen:[NSScreen mainScreen]];
    win.releasedWhenClosed = NO;
    win.movableByWindowBackground = YES;
    return win;
}

- (NSView *)createEventView {
    MPVEventView * view = [[MPVEventView alloc] initWithPlayer:_player];
    view.autoresizingMask = NSViewWidthSizable | NSViewHeightSizable;
    view.frame = kMPVExampleDefaultFrame;
    return view;
}

- (id <MPVExampleProtocol>)createExample:(Class)cls {
    id <MPVExampleProtocol> example = [[cls alloc] init];
    NSAssert(example, @"Cannot create example %@", cls);
    return example;
}

- (void)setUpNotifications {
    NSNotificationCenter * nc = [NSNotificationCenter defaultCenter];
    [nc addObserver:self selector:@selector(windowWillClose:)
               name:NSWindowWillCloseNotification object:_window];
    [nc addObserver:self selector:@selector(windowWillClose:)
               name:MPVPlayerWillShutdownNotification object:_player];
}

- (void)windowWillClose:(id)n {
    [self shutdown];
}

- (void)shutdown {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    if ([_window isVisible]) {
        [_window performClose:nil];
    }
    if (_player && _player.status == MPVPlayerStatusReadyToPlay) {
        [_player shutdown];
        _example = nil;
        _player = nil;
    }
}

- (void)dealloc {
    [self shutdown];
}

@end
