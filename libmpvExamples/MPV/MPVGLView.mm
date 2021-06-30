//
//  MPVGLView.mm
//  libmpvExamples
//
//  Created by Terminator on 2021/6/13.
//  Copyright © 2021年 home. All rights reserved.
//

#import "MPVGLView.h"

#import "CGLRenderer.h"
#import "DisplayLink.h"
#import "MPVClient.h"

[[clang::objc_direct_members]]
@implementation MPVGLView {
    MPV::CGLRenderer _cgl;
    DisplayLink _displayLink;
    MPVClient *_mpv;
    BOOL _initialized;
}
@synthesize client = _mpv, readyForDisplay = _initialized;

- (instancetype)initWithFrame:(NSRect)rect client:(nullable MPVClient *)mpv {
    if (!MPV::CGLRenderer::IsOpenGLFrameworkAvailable()) return nil;
    auto res = MPV::CGLRenderer::ChoosePixelFormat();
    if (!res) {
        NSLog(@"[MPVGLView] ChoosePixelFormat: %s", CGLErrorString(res));
        return nil;
    }
    auto pf = [[NSOpenGLPixelFormat alloc] initWithCGLPixelFormatObj:res];
    CGLReleasePixelFormat(res);
    
    if (!(self = [super initWithFrame:rect pixelFormat:pf])) return nil;
    if (!mpv) {
        mpv = [MPVClient new];
    }
    
    if (!mpv.isReadyToPlay) {
        NSLog(@"[MPVGLView] Client: %@ cannot be used for video playback", mpv);
        return nil;
    }
    _mpv = mpv;
    
    auto gl = self.openGLContext;
    if (const auto res = _cgl.init(reinterpret_cast<mpv_handle*>(mpv.handle),
                                   gl.CGLContextObj); !res) {
        NSLog(@"[MPVGLView] Cannot create CGLRenderer %s", res.Err.string());
        return nil;
    }
    [gl setValues:(GLint[]){1} forParameter:NSOpenGLContextParameterSwapInterval];
    
    static int flipY = 1;
    _cgl.setAuxParameter({.type = MPV_RENDER_PARAM_FLIP_Y, .data = &flipY});
    [self setUpResizeMode];
    _initialized = YES;
    
    return self;
}

- (void)destroy {
    if (!_initialized) return;
    _initialized = NO;
    if (_displayLink.isRunning()) {
        [self exitResizeMode];
    } else {
        [self exitPlaybackMode];
    }
    _cgl.deinit();
}

- (void)enterPlaybackMode {
    _cgl.onUpdate(&_cgl, [](void *ctx){
        const auto &cgl = *reinterpret_cast<MPV::CGLRenderer*>(ctx);
        cgl.async(ctx, [](void *ctx){
            const auto &cgl = *reinterpret_cast<MPV::CGLRenderer*>(ctx);
            cgl.setCurrent().draw().flush();
        });
    });
}

- (void)exitPlaybackMode {
    _cgl.onUpdate({}, {});
    _cgl.sync(^{}); // make sure the render queue is empty
}

- (void)setUpResizeMode {
    _displayLink.onUpdate(&_cgl,
    [](CVDisplayLinkRef CV_NONNULL, const CVTimeStamp * CV_NONNULL,
       const CVTimeStamp * CV_NONNULL, CVOptionFlags,
       CVOptionFlags * CV_NONNULL, void * CV_NULLABLE ctx) -> CVReturn {
        
        const auto &cgl = *reinterpret_cast<MPV::CGLRenderer*>(ctx);
        cgl.lock([&]{
            if (!cgl.needsDisplay()) return;
            cgl.setCurrent().update().drawUntimed().flush();
        });
        return kCVReturnSuccess;
    });
}

- (void)enterResizeMode {
    _displayLink.start();
}

- (void)exitResizeMode {
    _displayLink.stop();
}

//MARK:- Overrides

- (instancetype)initWithFrame:(NSRect)rect {
    return [self initWithFrame:rect client:nil];
}

- (void)dealloc {
    [self destroy];
}

- (void)setFrameSize:(NSSize)newSize {
    [super setFrameSize:newSize];
    _cgl.lock([&] {
        const auto size = [self convertSizeToBacking:newSize];
        _cgl.setSize(size.width, size.height);
    });
}

- (void)drawRect:(NSRect)dirtyRect {
    if (!_initialized) {
        [[NSColor blackColor] set];
        NSRectFill(dirtyRect);
        return;
    }
    if (_displayLink.isRunning()) {
        _cgl.lock([&]{
            _cgl.setCurrent().drawUntimed().flush();
        });
    } else {
        const auto &cgl = _cgl;
        _cgl.sync(^{
            cgl.setCurrent().draw().flush();
        });
    }
}

- (void)viewWillStartLiveResize {
    [super viewWillStartLiveResize];
    if (!_initialized) return;
    [self exitPlaybackMode];
    [self enterResizeMode];
}

- (void)viewDidEndLiveResize {
    [super viewDidEndLiveResize];
    if (!_initialized) return;
    [self exitResizeMode];
    [self enterPlaybackMode];
}

- (void)viewDidMoveToWindow {
    [super viewDidMoveToWindow];
    if (!_initialized) return;
    if (self.window) {
        [self enterPlaybackMode];
    } else {
        if (_displayLink.isRunning()) {
            [self exitResizeMode];
        } else {
            [self exitPlaybackMode];
        }
    }
}

- (BOOL)isOpaque {
    return YES;
}

- (BOOL)mouseDownCanMoveWindow {
    return YES;
}

@end
