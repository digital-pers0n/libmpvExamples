//
//  Window.m
//  libmpvExamples
//
//  Created by Terminator on 2019/08/01.
//  Copyright © 2019年 home. All rights reserved.
//

#import "Window.h"
#import "CocoaCB.h"
#import "MPVHelper.h"
#import "VideoLayer.h"
#import "EventsView.h"

@interface Window ()

@property (nonatomic) NSScreen *targetScreen;
@property (nonatomic) NSScreen *previousScreen;
@property (nonatomic) NSScreen *currentScreen;
@property (nonatomic) NSScreen *unfScreen;

@property (nonatomic) NSRect unfsContetnFrame;
@property (nonatomic) BOOL isInFullscreen;
@property (nonatomic) BOOL isAnimating;
@property (nonatomic) BOOL isMoving;
@property (nonatomic) BOOL forceTargetScreen;
@property (nonatomic) BOOL keepAspect;
@property (nonatomic) BOOL border;
@property (nonatomic) NSVisualEffectView *titleBarEffect;
@property (nonatomic) NSView *titleBar;
@property (nonatomic) CGFloat titleBarHeight;
@property (nonatomic) NSArray <NSButton *> *titleButtons;

@end

@implementation Window

#pragma mark - Init

- (instancetype)initWithContentRect:(NSRect)rect screen:(NSScreen *)screen view:(NSView *)view cocoaCB:(CocoaCB *)ccb {
    self = [super initWithContentRect:rect
                            styleMask: NSTitledWindowMask | NSClosableWindowMask | NSMiniaturizableWindowMask | NSResizableWindowMask
                              backing:NSBackingStoreBuffered
                                defer:NO
                               screen:screen];
    if (self) {
        _cocoaCB = ccb;
        _mpv = ccb.mpv;
        self.title = ccb.title;
        self.minSize = NSMakeSize(160, 90);
        self.collectionBehavior = NSWindowCollectionBehaviorFullScreenPrimary;
        self.delegate = self;
        [self.contentView addSubview:view];
        view.frame = self.contentView.frame;
        
        _unfsContetnFrame = [self convertRectToScreen:self.contentView.frame];
        _targetScreen = screen;
        _currentScreen = screen;
        _unfScreen = screen;
        [self initTitleBar];
        _border = YES;
    }
    return self;
}

- (void)initTitleBar {
    NSRect bounds = self.contentView.bounds;
    bounds.origin.y = NSHeight(bounds) - self.titleBarHeight;
    bounds.size.height = self.titleBarHeight;
    
    self.styleMask |= NSFullSizeContentViewWindowMask;
    self.titleBar.alphaValue = 0;
    self.titlebarAppearsTransparent =  YES;
    _titleBarEffect = [NSVisualEffectView.alloc initWithFrame:bounds];
    _titleBarEffect.alphaValue = 0;
    _titleBarEffect.blendingMode = NSVisualEffectBlendingModeWithinWindow;
    _titleBarEffect.autoresizingMask = NSViewWidthSizable | NSViewMinYMargin;

    [self.contentView addSubview:_titleBarEffect positioned:NSWindowAbove relativeTo:nil];
    
}

#pragma mark - Methods

- (void)showTitleBar {
    if (!_titleBarEffect || (!_border && !_isInFullscreen)) {
        return;
    }
    NSPoint loc = [_cocoaCB.view convertPoint:self.mouseLocationOutsideOfEventStream fromView:nil];
    for (NSButton *b in self.titleButtons) {
        b.hidden = NO;
    }
    
    [NSAnimationContext runAnimationGroup:^(NSAnimationContext * _Nonnull context) {
        context.duration = 0.20;
        self.titleBar.animator.alphaValue = 1;
        if (!_isInFullscreen && !_isAnimating) {
            _titleBarEffect.animator.alphaValue = 1;
        }
    } completionHandler:^{}];
    
    if (loc.y > self.titleBarHeight) {
        [self hideTitleBarDelayed];
    } else {
        [NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(hideTitleBar) object:nil];
    }
}

- (void)hideTitleBar {
    if (!_titleBarEffect) {
        return;
    }
    if (_isInFullscreen && !_isAnimating) {
        _titleBarEffect.alphaValue = 0;
    }
    [NSAnimationContext runAnimationGroup:^(NSAnimationContext * _Nonnull context) {
        context.duration = 0.20;
        self.titleBar.animator.alphaValue = 0;
        _titleBarEffect.animator.alphaValue = 0;
    } completionHandler:^{
        for (NSButton *b in self.titleButtons) {
            b.hidden = true;
        }
    }];
}

- (void)hideTitleBarDelayed {
    [NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(hideTitleBar) object:nil];
    [self performSelector:@selector(hideTitleBar) withObject:nil afterDelay:5];
}

-(void)setKeepAspect:(BOOL)keepAspect {
    _keepAspect = keepAspect;
    if (!_isInFullscreen) {
        _unfsContetnFrame = [self convertRectToScreen:self.contentView.frame];
    }
    if (keepAspect) {
        self.contentAspectRatio = _unfsContetnFrame.size;
    } else {
        self.resizeIncrements = NSMakeSize(1.0, 1.0);
    }
}
- (void)setBorder:(BOOL)border {
    _border = border;
    if (!border) {
        [self hideTitleBar];
    }
}

- (NSView *)titleBar {
    return [self standardWindowButton:NSWindowCloseButton].superview;
}

- (CGFloat)titleBarHeight {
    return [NSWindow frameRectForContentRect:NSZeroRect styleMask:NSTitledWindowMask].size.height;
}

- (NSArray<NSButton *> *)titleButtons {
    return @[[self standardWindowButton:NSWindowCloseButton],
             [self standardWindowButton:NSWindowMiniaturizeButton],
             [self standardWindowButton:NSWindowZoomButton]];
}

#pragma mark - Overrides

- (BOOL)canBecomeKeyWindow {
    return YES;
}

- (BOOL)canBecomeMainWindow {
    return YES;
}

- (void)setStyleMask:(NSUInteger)styleMask {
    id responder = self.firstResponder;
    id windowTitle = self.title;
    super.styleMask = styleMask;
    [self makeFirstResponder:responder];
    self.title = windowTitle;
}


- (void)toggleFullScreen:(id)sender {
    
    if (_isAnimating) {
        return;
    }
    _isAnimating = YES;
    
    if (!_isInFullscreen) {
        _unfsContetnFrame = [self convertRectToScreen:self.contentView.frame];
        _unfScreen = self.screen;
    }
    
    if ([_mpv getBoolProperty:@"native-fs"]) {
        [super toggleFullScreen:sender];
    } else {
        if (!_isInFullscreen) {
            NSApp.presentationOptions = NSApplicationPresentationAutoHideDock | NSApplicationPresentationAutoHideMenuBar;
            _isInFullscreen = YES;
        } else {
            NSApp.presentationOptions = 0;
            _isInFullscreen = NO;
        }
        [self zoom:sender];
        [_cocoaCB.layer update];
    }
}

#pragma mark - NSWindowDelegate

- (void)windowDidEnterFullScreen:(NSNotification *)notification {
    _isInFullscreen = YES;
    [self showTitleBar];
}

- (void)windowDidExitFullScreen:(NSNotification *)notification {
    _isInFullscreen = NO;
    _cocoaCB.view.layerContentsPlacement = NSViewLayerContentsPlacementScaleProportionallyToFit;
}

- (void)windowWillStartLiveResize:(NSNotification *)notification {
    _cocoaCB.layer.inLiveResize = YES;
}

- (void)windowDidEndLiveResize:(NSNotification *)notification {
    _cocoaCB.layer.inLiveResize = NO;
}

@end
