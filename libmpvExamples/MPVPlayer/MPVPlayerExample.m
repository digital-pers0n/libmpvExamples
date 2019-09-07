//
//  MPVPlayerExample.m
//  libmpvExamples
//
//  Created by Terminator on 2019/08/29.
//  Copyright © 2019年 home. All rights reserved.
//

#import "MPVPlayerExample.h"
#import "MPVPlayer.h"
#import "MPVOpenGLView.h"
#import "MPVPlayerWindow.h"

@interface MPVPlayerExample () {
    MPVPlayerWindow *_window;
}

@property MPVOpenGLView *openGLView;

@end

@implementation MPVPlayerExample

- (instancetype)init
{
    self = [super init];
    if (self) {
        _window = [MPVPlayerWindow.alloc initWithContentRect:NSMakeRect(0, 0, 1280, 720)
                                                   styleMask: NSTitledWindowMask | NSClosableWindowMask | NSMiniaturizableWindowMask | NSResizableWindowMask
                                                     backing:NSBackingStoreBuffered
                                                       defer:NO ];
        _window.releasedWhenClosed = NO;
        
        
        if ([self createOpenGLView] != 0) {
            NSLog(@"Failed to initialize MPVOpenGLView");
            return nil;
        }
        
        [_window center];
        [_window makeKeyAndOrderFront:nil];
    
    }
    return self;
}

- (int)createOpenGLView {
    _openGLView = [MPVOpenGLView.alloc initWithFrame:NSMakeRect(0, 0, 1280, 720)];
    if (!_openGLView) {
        return -1;
    }
    _openGLView.autoresizingMask = NSViewWidthSizable | NSViewHeightSizable;
    _openGLView.translatesAutoresizingMaskIntoConstraints = NO;
    _player = _openGLView.player;
    [_window.contentView addSubview:_openGLView];
    return 0;
}

- (void)dealloc {
    [self shutdown];
    _player = nil;
    _openGLView = nil;
    _window = nil;
}

- (void)shutdown {
    [_window performClose:nil];
    if (_player.status == MPVPlayerStatusReadyToPlay) {
        [_player shutdown];
    }
    [_openGLView removeFromSuperview];
}

@end
