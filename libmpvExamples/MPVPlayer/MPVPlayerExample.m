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
#import "MPVPlayerLayer.h"
#import "MPVPlayerView.h"
#import "MPVHybridView.h"
#import "MPVPlayerWindow.h"

@interface MPVPlayerExample () {
    MPVPlayerWindow *_window;
}

@property MPVOpenGLView *openGLView;
@property MPVPlayerLayer *openGLLayer;
@property MPVPlayerView *playerView;
@property MPVHybridView *hybridView;

@end

@implementation MPVPlayerExample

- (instancetype)init {
    return [self initWithExample:MPVPlayerExampleNSView];
}

- (instancetype)initWithExample:(MPVPlayerExampleType)type
{
    self = [super init];
    if (self) {
        _window = [MPVPlayerWindow.alloc initWithContentRect:NSMakeRect(0, 0, 1280, 720)
                                                   styleMask: NSTitledWindowMask | NSClosableWindowMask | NSMiniaturizableWindowMask | NSResizableWindowMask
                                                     backing:NSBackingStoreBuffered
                                                       defer:NO ];
        _window.releasedWhenClosed = NO;
        
        switch (type) {
            case MPVPlayerExampleNSOpenGLView:
                if ([self createOpenGLView] != 0) {
                    NSLog(@"Failed to initialize MPVOpenGLView");
                    return nil;
                }
                break;
                
            case MPVPlayerExampleNSView:
                if ([self createPlayerView] != 0) {
                    NSLog(@"Failed to initialize MPVPlayerView");
                    return nil;
                }
                break;
            case MPVPlayerExampleHybridView:
                if ([self createHybridView] != 0) {
                    NSLog(@"Failed to initialize MPVHybridView");
                    return nil;
                }
                break;
                
            case MPVPlayerExampleCAOpenGLLayer:
                if ([self createOpenGLLayer] != 0) {
                    NSLog(@"Failed to initialize MPVPlayerLayer");
                    return nil;
                }
                break;
                
            default:
                break;
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

- (int)createPlayerView {
    _playerView = [[MPVPlayerView alloc] initWithFrame:NSMakeRect(0, 0, 1280, 720)];
    if (!_playerView) {
        return -1;
    }
    _playerView.autoresizingMask = NSViewWidthSizable | NSViewHeightSizable;
    _playerView.translatesAutoresizingMaskIntoConstraints = NO;
    _player = _playerView.player;
    [_window.contentView addSubview:_playerView];
    
    return 0;
}

- (int)createHybridView {
    _hybridView = [[MPVHybridView alloc] initWithFrame:NSMakeRect(0, 0, 1280, 720)];
    if (!_hybridView) {
        return -1;
    }
    _hybridView.autoresizingMask = NSViewWidthSizable | NSViewHeightSizable;
    _hybridView.translatesAutoresizingMaskIntoConstraints = NO;
    _player = _hybridView.player;
    [_window.contentView addSubview:_hybridView];
    
    return 0;
}

- (int)createOpenGLLayer {
    _openGLLayer = MPVPlayerLayer.new;
    if (!_openGLLayer) {
        return -1;
    }
    _openGLLayer.autoresizingMask = kCALayerWidthSizable | kCALayerHeightSizable;
    _openGLLayer.backgroundColor = NSColor.blackColor.CGColor;
    _player = _openGLLayer.player;
    
    NSView *contentView = _window.contentView;
    contentView.layer = _openGLLayer;
    contentView.wantsLayer = YES;
    contentView.layerContentsPlacement = NSViewLayerContentsPlacementScaleProportionallyToFit;
    
    return 0;
}

- (void)dealloc {
    [self shutdown];
    _player = nil;
    _openGLView = nil;
    _playerView = nil;
    _openGLLayer = nil;
    _window = nil;
}

- (void)shutdown {
    [_window performClose:nil];
    if (_player.status == MPVPlayerStatusReadyToPlay) {
        [_player shutdown];
    }
    [_openGLView removeFromSuperview];
    [_playerView removeFromSuperview];
    _window.contentView.wantsLayer = NO;
}

@end
