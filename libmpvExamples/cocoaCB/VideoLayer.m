//
//  VideoLayer.m
//  libmpvExamples
//
//  Created by Terminator on 2019/08/01.
//  Copyright © 2019年 home. All rights reserved.
//

#import "VideoLayer.h"
#import "MPVHelper.h"
#import "CocoaCB.h"
#import "Window.h"

@import OpenGL.GL;
@import OpenGL.GL3;

@implementation VideoLayer

- (MPVHelper *)mpv {
    return _cocoaCB.mpv;
}

#pragma mark - Init

- (instancetype)initWithCocoaCB:(CocoaCB *)ccb
{
    _cocoaCB = ccb;
    _mpv = ccb.mpv;
    self = [super init];
    if (self) {
        _queue = dispatch_get_main_queue();
        _videoLock = NSLock.new;
        _displayLock = NSLock.new;
        self.autoresizingMask = kCALayerWidthSizable | kCALayerHeightSizable;
        self.backgroundColor = NSColor.blackColor.CGColor;
        _cglPixelFormat = [self copyCGLPixelFormatForDisplayMask:0];
        CGLCreateContext(_cglPixelFormat, nil, &_cglContext);
        GLint i = 1;
        CGLSetParameter(_cglContext, kCGLCPSwapInterval, &i);
        CGLSetCurrentContext(_cglContext);
        
        [_mpv initRender];
        [_mpv setRenderUpdateCallback:updateCallback context:self];
    }
    return self;
}

- (instancetype)initWithLayer:(id)layer {
    if ([layer isKindOfClass:VideoLayer.class]) {
        _cocoaCB = [layer cocoaCB];
        self = super.init;
    }
    return self;
}

#pragma mark - Overrides

- (BOOL)canDrawInCGLContext:(CGLContextObj)ctx pixelFormat:(CGLPixelFormatObj)pf forLayerTime:(CFTimeInterval)t displayTime:(const CVTimeStamp *)ts {
    if (!_inLiveResize) {
        self.asynchronous = NO;
    }
    return (_mpv && _cocoaCB.backendState == MPVStateInitialized);
}

- (void)drawInCGLContext:(CGLContextObj)ctx pixelFormat:(CGLPixelFormatObj)pf forLayerTime:(CFTimeInterval)t displayTime:(const CVTimeStamp *)ts {
    _needsFlip = NO;
    _canDrawOffScreen = YES;
    
    [self draw:ctx];
    
}

- (CGLPixelFormatObj)copyCGLPixelFormatForDisplayMask:(uint32_t)mask {
    CGLPixelFormatAttribute glAttributes[] = {
        kCGLPFAOpenGLProfile,  (CGLPixelFormatAttribute)kCGLOGLPVersion_3_2_Core,
        kCGLPFAAccelerated,
        kCGLPFADoubleBuffer,
        kCGLPFABackingStore,
        kCGLPFAAllowOfflineRenderers,
        kCGLPFASupportsAutomaticGraphicsSwitching,
        0
    };
    CGLPixelFormatObj pix;
    GLint npix = 0;
    CGLError error = CGLChoosePixelFormat(glAttributes, &pix, &npix);
    if (error != kCGLNoError) {
        NSLog(@"CGLChoosePixelFormat() -> %u", error);
        return nil;
    }
    return pix;
}

- (CGLContextObj)copyCGLContextForPixelFormat:(CGLPixelFormatObj)pf {
    self.contentsScale = _cocoaCB.window.backingScaleFactor;
    return _cglContext;
}

- (void)display {
    [_displayLock lock];
    BOOL isUpdate = _needsFlip;
    [super display];
    [CATransaction flush];
    if (isUpdate) {
        if (!(_cocoaCB.window.occlusionState & NSWindowOcclusionStateVisible) &&
            _needsFlip &&
            _canDrawOffScreen)
        {
            CGLSetCurrentContext(_cglContext);
            [self draw:_cglContext];
        } else if (_needsFlip) {
            [self update];
        }
    }
    [_displayLock unlock];
}

#pragma mark - Methods

- (void)setNeedsICCUpdate:(BOOL)value {
    if (value) {
        [self update];
    }
}

- (void)setInLiveResize:(BOOL)inLiveResize {
    if (inLiveResize) {
        self.asynchronous = YES;
    }
    [self update];
    _inLiveResize = inLiveResize;
}

- (void)draw:(CGLContextObj)ctx {
    if (_draw >= VideoLayerDrawAtomic) {
        if (_draw == VideoLayerDrawAtomic) {
            _draw = VideoLayerDrawAtomicEnd;
        } else {
            [self atomicDrawingEnd];
        }
    }
    
    [self updateSurfaceSize];
    [_mpv drawRender:_surfaceSize];
    CGLFlushDrawable(ctx);
}

- (void)updateSurfaceSize {
    GLint dims[] = { 0, 0, 0, 0 };
    glGetIntegerv(GL_VIEWPORT, dims);
    _surfaceSize = NSMakeSize(dims[2], dims[3]);
    if (NSEqualSizes(_surfaceSize, NSZeroSize)) {
        _surfaceSize = self.bounds.size;
        _surfaceSize.width *= self.contentsScale;
        _surfaceSize.height *= self.contentsScale;
    }
}

- (void)atomicDrawingStart {
    if (_draw == VideoLayerDrawNormal && _hasVideo) {
        NSDisableScreenUpdates();
        _draw = VideoLayerDrawAtomic;
    }
}

- (void)atomicDrawingEnd {
    if (_draw >= VideoLayerDrawAtomic) {
        NSEnableScreenUpdates();
        _draw = VideoLayerDrawNormal;
    }
}

- (void)setVideo:(BOOL)state {
    [_videoLock lock];
    _hasVideo = state;
    [_videoLock unlock];
}

static void _update_layer(VideoLayer *obj) {
    [obj->_videoLock lock];
    if (!obj->_inLiveResize && obj->_hasVideo) {
        obj->_needsFlip = YES;
        [obj display];
    }
    [obj->_videoLock unlock];
}

- (void)update {
    dispatch_async_f(_queue, (__bridge void *)self, (void *)_update_layer);
}

static void updateCallback(void *ctx) {
    VideoLayer *layer = (__bridge id)ctx;
    [layer update];
}

@end
