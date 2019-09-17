//
//  MPVHybridView.m
//  libmpvExamples
//
//  Created by Terminator on 2019/09/14.
//  Copyright © 2019年 home. All rights reserved.
//

#import <QuartzCore/QuartzCore.h>

#import "MPVHybridView.h"

#import "MPVPlayer.h"
#import <mpv/render_gl.h>

#import <dlfcn.h>           //    dlsym()

@import OpenGL.GL;
@import OpenGL.GL3;

extern void *g_opengl_framework_handle;

typedef struct mpv_data_ {
    mpv_render_context      *render_context;
    CGLContextObj           cgl_context;
    mpv_opengl_fbo          opengl_fbo;
    mpv_render_param        render_params[3];
} mpv_data;


@interface MPVVideoLayer : CAOpenGLLayer {
    mpv_data *_mpv;
    BOOL _shouldDraw;
}

- (instancetype)initWithMPVData:(mpv_data *)data;
@property BOOL shouldDraw;
@property dispatch_queue_t render_queue;

@end

@implementation MPVVideoLayer

- (instancetype)initWithMPVData:(mpv_data *)data {
    
    self = [super init];
    if (self) {
        _mpv = data;
    }
    return self;
}

#pragma mark - Overrides

- (BOOL)canDrawInCGLContext:(CGLContextObj)ctx pixelFormat:(CGLPixelFormatObj)pf forLayerTime:(CFTimeInterval)t displayTime:(const CVTimeStamp *)ts {
    return (self.shouldDraw && _mpv && _mpv->render_context != nil);
}

- (void)drawInCGLContext:(CGLContextObj)ctx pixelFormat:(CGLPixelFormatObj)pf forLayerTime:(CFTimeInterval)t displayTime:(const CVTimeStamp *)ts {
    _draw_frame(self);

}

- (CGLContextObj)copyCGLContextForPixelFormat:(CGLPixelFormatObj)pf {
    return _mpv->cgl_context;
}

#pragma mark - functions

static inline void _draw_frame(__unsafe_unretained MPVVideoLayer *obj) {
 
    mpv_data *mpv = obj->_mpv;
    CGLLockContext(mpv->cgl_context);
    CGLSetCurrentContext(mpv->cgl_context);
    static GLint dims[4] = { 0 };
    
    glGetIntegerv(GL_VIEWPORT, dims);
    GLint width = dims[2];
    GLint height = dims[3];
    if (width == 0 || height == 0) {
        NSSize surfaceSize = obj.bounds.size;;
        width = surfaceSize.width * obj.contentsScale;
        height = surfaceSize.height * obj.contentsScale;
    }
    
    mpv->opengl_fbo.w = width;
    mpv->opengl_fbo.h = height;
    
    GLint i = 0;
    glGetIntegerv(GL_DRAW_FRAMEBUFFER_BINDING, &i);
    
    if (i) {
        mpv->opengl_fbo.fbo = i;
    }

    mpv_render_context_render(mpv->render_context, mpv->render_params);
    glFlush();
    CGLUnlockContext(mpv->cgl_context);
}

@end

@interface MPVHybridView () {
    dispatch_queue_t _render_queue;
    NSOpenGLContext *_glContext;
    MPVVideoLayer *_videoLayer;
    mpv_data _mpv;
}
@end

@implementation MPVHybridView

#pragma mark - Initialization

- (instancetype)initWithFrame:(CGRect)frame
{
    NSOpenGLPixelFormat *pf = [self createOpenGLPixelFormat];
    if (!pf) {
        NSLog(@"Failed to create NSOpenGLPixelFormat object.");
        return nil;
    }
    
    self = [super initWithFrame:frame pixelFormat:pf];
    if (self) {
        if ([self createMPVPlayer] != 0) {
            NSLog(@"Failed to create MPVPlayer instance. -> %@", _player.error.localizedDescription);
            return nil;
        }
        
        NSNotificationCenter *nc = [NSNotificationCenter defaultCenter];
        [nc addObserver:self
               selector:@selector(playerWillShutdown:)
                   name:MPVPlayerWillShutdownNotification
                 object:_player];
        
        dispatch_queue_attr_t attr = dispatch_queue_attr_make_with_qos_class(
                                                                             DISPATCH_QUEUE_SERIAL,
                                                                             QOS_CLASS_USER_INTERACTIVE, 0);
        _render_queue = dispatch_queue_create("com.home.MPVHybridView.render-queue", attr);
        _glContext = self.openGLContext;
        _mpv.cgl_context = _glContext.CGLContextObj;
        self.canDrawConcurrently = YES;
        _mpv.opengl_fbo = (mpv_opengl_fbo) { .fbo = 1, .w = NSWidth(frame), .h = NSHeight(frame) };
    }

    return self;
}

- (NSOpenGLPixelFormat *)createOpenGLPixelFormat {
    NSOpenGLPixelFormatAttribute attributes[] = {
        NSOpenGLPFANoRecovery,
        NSOpenGLPFAAllowOfflineRenderers,
        NSOpenGLPFAAccelerated,
        NSOpenGLPFAOpenGLProfile, NSOpenGLProfileVersion3_2Core,
        0
    };
    
    return [[NSOpenGLPixelFormat alloc] initWithAttributes:attributes];
}

- (int)createMPVPlayer {
    _player = MPVPlayer.new;
    if (_player.status == MPVPlayerStatusFailed) {
        return -1;
    }
    return 0;
}

- (int)createMPVRenderContext {
    
    [_glContext makeCurrentContext];
    [_glContext update];
    
    static int mpv_flip_y = 1;
    
    
    _mpv.render_params[0] = (mpv_render_param) { .type = MPV_RENDER_PARAM_OPENGL_FBO, .data = &_mpv.opengl_fbo };
    _mpv.render_params[1] = (mpv_render_param) { .type = MPV_RENDER_PARAM_FLIP_Y,     .data = &mpv_flip_y };
    _mpv.render_params[2] = (mpv_render_param) { 0 };
    
    mpv_opengl_init_params mpv_opengl_init_params = {
        .get_proc_address = &dlsym,
        .get_proc_address_ctx = g_opengl_framework_handle
    };
    
    mpv_render_param params[] = {
        { .type = MPV_RENDER_PARAM_API_TYPE,           .data = MPV_RENDER_API_TYPE_OPENGL },
        { .type = MPV_RENDER_PARAM_OPENGL_INIT_PARAMS, .data = &mpv_opengl_init_params },
        { 0 }
    };
    
    return mpv_render_context_create(&_mpv.render_context, _player.mpv_handle, params);
}

- (void)destroyMPVRenderContext {
    [_glContext clearDrawable];
    mpv_render_context_set_update_callback(_mpv.render_context, NULL, NULL);
    mpv_render_context_free(_mpv.render_context);
    _mpv.render_context = NULL;
}

- (void)dealloc {
    if (_mpv.render_context) {
        [self destroyMPVRenderContext];
    }
}

#pragma mark - Overrides

- (void)drawRect:(NSRect)dirtyRect {
    if (_mpv.render_context) {
        if (!_videoLayer.shouldDraw) {
            render_frame_sync(self);
            [self update];
        }
    }
}

static inline void reshape_async(MPVHybridView *obj) {
    dispatch_async_f(obj->_render_queue, (__bridge void *)obj, &reshape);
}

- (void)reshape {
    if (_videoLayer.shouldDraw) {
        return;
    }
    reshape_async(self);
}

static void reshape(void *ctx) {
    __unsafe_unretained MPVHybridView *obj = (__bridge id)ctx;
    mpv_data *mpv = &obj->_mpv;
    CGLLockContext(mpv->cgl_context);
    {
        NSRect bounds = [obj convertRectToBacking:obj.bounds];
        mpv->opengl_fbo.w = NSWidth(bounds);
        mpv->opengl_fbo.h = NSHeight(bounds);
    }
    CGLUnlockContext(mpv->cgl_context);
}

static inline void context_update_async(dispatch_queue_t queue, NSOpenGLContext *ctx) {
    dispatch_async_f(queue, (__bridge void *)ctx, &context_update);
}

- (void)update {
    if (_videoLayer.shouldDraw) { return; }
    context_update_async(_render_queue, _glContext);
}

static void context_update(void *ctx) {
    __unsafe_unretained NSOpenGLContext *glContext = (__bridge id)ctx;
    [glContext makeCurrentContext];
    [glContext update];
}


- (void)viewDidMoveToWindow {
    if (self.window) {
        if (!_mpv.render_context) {
            int error;
            if ((error = [self createMPVRenderContext]) != MPV_ERROR_SUCCESS) {
                NSLog(@"Failed to create mpv_render_context. -> %s", mpv_error_string(error));
                return;
            }
            mpv_render_context_set_update_callback(_mpv.render_context, render_callback, (__bridge void *)self);
            _videoLayer = [[MPVVideoLayer alloc] initWithMPVData:&_mpv];
            _videoLayer.autoresizingMask = kCALayerWidthSizable | kCALayerHeightSizable;
            _videoLayer.backgroundColor = NSColor.blackColor.CGColor;
            _videoLayer.asynchronous = YES;
            _videoLayer.contentsScale = self.window.backingScaleFactor;
            self.layerContentsPlacement = NSViewLayerContentsPlacementScaleProportionallyToFit;
            self.layerContentsRedrawPolicy =   NSViewLayerContentsRedrawDuringViewResize;
            self.wantsLayer = NO;
        }
    }
}

- (void)viewWillStartLiveResize {
    [super viewWillStartLiveResize];
    if (_mpv.render_context) {
        _videoLayer.shouldDraw = YES;
        self.layer = _videoLayer;
        self.wantsLayer = YES;
        mpv_render_context_set_update_callback(_mpv.render_context, &resize_callback, (__bridge void *)self );
    }
}

- (void)viewDidEndLiveResize {
    [super viewDidEndLiveResize];
    if (_mpv.render_context) {
        self.layer = nil;
        self.wantsLayer = NO;
        _videoLayer.shouldDraw = NO;
        mpv_render_context_set_update_callback(_mpv.render_context, &render_callback, (__bridge void *)self );
    }
}

- (BOOL)isOpaque {
    return YES;
}

- (BOOL)mouseDownCanMoveWindow {
    return YES;
}

- (BOOL)wantsDefaultClipping {
    return NO;
}

#pragma mark - Notifications

- (void)playerWillShutdown:(NSNotification *)n {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    if (_mpv.render_context) {
        [self destroyMPVRenderContext];
    }
}

#pragma mark - mpv render functions

static void render_frame(void *ctx) {
    mpv_data *obj = (mpv_data *)ctx;
    CGLSetCurrentContext(obj->cgl_context);
    mpv_render_context_render(obj->render_context, obj->render_params);
    glFlush();
}

__attribute__((flatten))
static void render_frame_safe(void *ctx)  {
    mpv_data *obj = (mpv_data *)ctx;
    CGLContextObj cgl = obj->cgl_context;
    CGLLockContext(cgl);
    {
        render_frame(ctx);
    }
    CGLUnlockContext(cgl);
}

static inline void render_frame_async(__unsafe_unretained MPVHybridView *obj) {
    dispatch_async_f(obj->_render_queue, &obj->_mpv, &render_frame);
}

static inline void render_frame_sync(__unsafe_unretained MPVHybridView *obj) {
    dispatch_sync_f(obj->_render_queue, &obj->_mpv, &render_frame_safe);
 
}

static void render_callback(void *ctx) {
    render_frame_async((__bridge id)ctx);
}


static void render_resize(void *ctx) {
    __unsafe_unretained MPVVideoLayer *obj = (__bridge id)ctx;
    [obj setNeedsDisplay];
    [CATransaction flush];
}

static inline void render_resize_async(MPVHybridView *obj) {
    dispatch_async_f(
                     obj->_render_queue,
    (__bridge void *)obj->_videoLayer,
                     &render_resize);
}

static void resize_callback(void *ctx) {
    MPVHybridView *obj = (__bridge id)ctx;
    render_resize_async(obj);
}

@end
