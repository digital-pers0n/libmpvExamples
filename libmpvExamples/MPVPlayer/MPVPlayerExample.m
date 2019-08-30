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

        _openGLView = [MPVOpenGLView.alloc initWithFrame:NSMakeRect(0, 0, 1280, 720)];
        if (!_openGLView) {
            NSLog(@"Failed to initialize MPVOpenGLView instance.");
            return nil;
        }
        _openGLView.autoresizingMask = NSViewWidthSizable | NSViewHeightSizable;
        _openGLView.translatesAutoresizingMaskIntoConstraints = NO;
        
        _window = [MPVPlayerWindow.alloc initWithContentRect:NSMakeRect(0, 0, 1280, 720)
                                                   styleMask: NSTitledWindowMask | NSClosableWindowMask | NSMiniaturizableWindowMask | NSResizableWindowMask
                                                     backing:NSBackingStoreBuffered
                                                       defer:NO ];
        _window.releasedWhenClosed = NO;
        
        [_window center];
        [_window makeKeyAndOrderFront:nil];
        
        _player = _openGLView.player;
        
        [_window.contentView addSubview:_openGLView];
    }
    return self;
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
