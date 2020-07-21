//
//  MPVIOSurfaceView.m
//  libmpvExamples
//
//  Created by Terminator on 2020/04/02.
//  Copyright © 2020年 home. All rights reserved.
//
//  Functions
//
//  CreateTransparentIOSurface()
//  CreateTextureForIOSurface()
//  CreateFBOForTexture()
//
//  are based on:
//
//  IOSurface compositing
//
//  Created by Markus Stange on 2017-12-21.
//  Copyright © 2017 Markus Stange. All rights reserved.

#import "MPVIOSurfaceView.h"

#import "MPVPlayer.h"
#import <mpv/render_gl.h>
#import <pthread/pthread.h>
#import <pthread/pthread_spis.h>
#import <stdatomic.h>
#import "MPVPlayerProperties.h"

#import <dlfcn.h>           //    dlsym()

@import OpenGL.GL;
@import OpenGL.GL3;
@import QuartzCore.CATransaction;

extern void *g_opengl_framework_handle;

typedef struct mpv_data_ {
    mpv_render_context          *render_context;
    mpv_render_param            render_params[3];
    mpv_opengl_fbo              opengl_fbo;
    struct _CGLContextObject    *cgl_ctx;
    pthread_mutex_t             gl_lock;
    void *                      layer;
    GLuint                      surface_texture;
} mpv_data;

// Private CALayer API.
@interface CALayer (Private)
- (void)setContentsChanged;
@property BOOL allowsGroupBlending;
@property BOOL canDrawConcurrently;
@property BOOL contentsOpaque;
@property BOOL hitTestsAsOpaque;
@property BOOL needsLayoutOnGeometryChange;
@property BOOL shadowPathIsBounds;
@end

static IOSurfaceRef
CreateTransparentIOSurface(int aWidth, int aHeight)
{
    NSDictionary* dict = @{
                           (id)kIOSurfaceWidth: @((int)aWidth),
                           (id)kIOSurfaceHeight: @((int)aHeight),
                           (id)kIOSurfaceBytesPerElement: @4,
                           (id)kIOSurfacePixelFormat: @((int)kCVPixelFormatType_32BGRA),
                           };
    IOSurfaceRef surf = IOSurfaceCreate((CFDictionaryRef)dict);
    return surf;
}

static GLuint
CreateTextureForIOSurface(CGLContextObj cglContext, IOSurfaceRef surf)
{
    GLuint texture;
    glGenTextures(1, &texture);

    glBindTexture(GL_TEXTURE_RECTANGLE_ARB, texture);

//    glTexParameteri(GL_TEXTURE_RECTANGLE_ARB,
//                    GL_TEXTURE_MIN_FILTER, GL_NEAREST);
//    glTexParameteri(GL_TEXTURE_RECTANGLE_ARB,
//                    GL_TEXTURE_MAG_FILTER, GL_NEAREST);

    CGLError rv =
    CGLTexImageIOSurface2D(cglContext, GL_TEXTURE_RECTANGLE_ARB,
                           GL_RGBA, // internal format
                           (GLsizei)IOSurfaceGetWidth(surf),
                           (GLsizei)IOSurfaceGetHeight(surf),
                           GL_BGRA, // format
                           GL_UNSIGNED_INT_8_8_8_8_REV, // type
                           surf, 0);

    if (rv != 0) {
        NSLog(@"CGLError: %d", rv);
    }
    glBindTexture(GL_TEXTURE_RECTANGLE_ARB, 0);
    return texture;
}

static GLuint
CreateFBOForTexture(GLuint texture)
{
    GLuint framebuffer;
    glGenFramebuffers(1, &framebuffer);
    
    glBindFramebuffer(GL_FRAMEBUFFER, framebuffer);
    
    glBindTexture(GL_TEXTURE_RECTANGLE_ARB, texture);

    glFramebufferTexture2D(GL_FRAMEBUFFER, GL_COLOR_ATTACHMENT0,
                           GL_TEXTURE_RECTANGLE_ARB, texture, 0);
    
    GLenum status = glCheckFramebufferStatus(GL_FRAMEBUFFER);
    if (status != GL_FRAMEBUFFER_COMPLETE) {
        NSLog(@"Framebuffer incomplete: %u", status);
    }
    glBindFramebuffer(GL_FRAMEBUFFER, 0);
    glBindTexture(GL_TEXTURE_RECTANGLE_ARB, 0);
    return framebuffer;
}

@interface MPVIOSurfaceView () {
    NSOpenGLContext *_glContext;
    mpv_data _mpv;
    CVDisplayLinkRef _cvdl;
    CVDisplayLinkRef _cvdl_resize;
    __weak CALayer *_layer;
    BOOL _isIdle;
}
@end

@implementation MPVIOSurfaceView

#pragma mark - Initialization

- (instancetype)initWithFrame:(NSRect)frame
{
    
    NSOpenGLPixelFormat *pf = [self createOpenGLPixelFormat];
    if (!pf) {
        NSLog(@"Cannot create NSOpenGLPixelFormat object.");
        return nil;
    }
    _glContext = [[NSOpenGLContext alloc] initWithFormat:pf shareContext:nil];
    if (!_glContext) {
        NSLog(@"Cannot create NSOpenGLContext object.");
        return nil;
    }
    self = [super initWithFrame:frame];
    if (self) {
        if ([self createMPVPlayer] != 0) {
            NSLog(@"Cannot create MPVPlayer instance. -> %@", _player.error.localizedDescription);
            _player = nil;
            return nil;
        }
        
        GLint opaque = 1;
        [_glContext setValues:&opaque forParameter:NSOpenGLContextParameterSurfaceOpacity];
        GLint swapInt = 1;
        [_glContext setValues:&swapInt forParameter:NSOpenGLContextParameterSwapInterval];
        
        NSNotificationCenter *nc = [NSNotificationCenter defaultCenter];
        [nc addObserver:self
               selector:@selector(playerWillShutdown:)
                   name:MPVPlayerWillShutdownNotification
                 object:_player];
        
        [nc addObserver:self
               selector:@selector(didStartPlayback:)
                   name:MPVPlayerDidLoadFileNotification
                 object:_player];
        
        [nc addObserver:self
               selector:@selector(playerDidEnterIdleMode:)
                   name:MPVPlayerDidEnterIdleModeNotification
                 object:_player];
        
        _mpv.cgl_ctx = _glContext.CGLContextObj;

        CALayer* layer = [CALayer layer];
        layer.opaque = YES;
        layer.contentsGravity = kCAGravityResizeAspect;
        layer.backgroundColor = [[NSColor blackColor] CGColor];
        layer.anchorPoint = CGPointZero;
        layer.position = CGPointZero;
        layer.bounds = CGRectMake(0, 0, 640, 480);
        layer.doubleSided = NO;
        _layer = layer;
        
        NSSize  surfaceSize = [self convertRectToBacking:frame].size;
        _mpv.opengl_fbo.w = surfaceSize.width;
        _mpv.opengl_fbo.h = surfaceSize.height;

        _mpv.layer = (__bridge void *)layer;
        //self.layer = layer;
        self.wantsLayer = YES;
        self.layer.opaque = YES;
        self.layer.backgroundColor = [[NSColor blackColor] CGColor];
        [self.layer addSublayer:layer];

        self.layerContentsRedrawPolicy =  NSViewLayerContentsRedrawDuringViewResize;
        
    }
    return self;
}

- (NSOpenGLPixelFormat *)createOpenGLPixelFormat {
    NSOpenGLPixelFormatAttribute attributes[] = {
        NSOpenGLPFANoRecovery,
        NSOpenGLPFAAllowOfflineRenderers,
        NSOpenGLPFAAccelerated,
        NSOpenGLPFADoubleBuffer,
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
    
    _mpv.render_params[0] = (mpv_render_param) {
        .type = MPV_RENDER_PARAM_OPENGL_FBO,
        .data = &_mpv.opengl_fbo
    };
    
    if (NSAppKitVersionNumber < NSAppKitVersionNumber10_12) {
        // On macOS 10.11 there will be flickering without this parameter.
        static int block_for_target = 0;
        _mpv.render_params[1] = (mpv_render_param) {
            .type = MPV_RENDER_PARAM_BLOCK_FOR_TARGET_TIME,
            .data = &block_for_target
        };
    } else {
        _mpv.render_params[1] =  (mpv_render_param) { 0 };
    }
    
    _mpv.render_params[2] = (mpv_render_param) { 0 };
    
    mpv_opengl_init_params mpv_opengl_init_params = {
        .get_proc_address = &dlsym,
        .get_proc_address_ctx = g_opengl_framework_handle
    };
    
    int flag = 1;
    mpv_render_param params[] = {
        {
            .type = MPV_RENDER_PARAM_API_TYPE,
            .data = MPV_RENDER_API_TYPE_OPENGL
        },
        {
            .type = MPV_RENDER_PARAM_OPENGL_INIT_PARAMS,
            .data = &mpv_opengl_init_params
        },
        {
            .type = MPV_RENDER_PARAM_ADVANCED_CONTROL,
            .data = &flag
        },
        { 0 }
    };
    
   _mpv.opengl_fbo.internal_format =  GL_RGBA;

    return mpv_render_context_create(&_mpv.render_context, _player.mpv_handle, params);
}

- (void)destroyMPVRenderContext {
    mpv_render_context_set_update_callback(_mpv.render_context, nil, nil);
    if (_cvdl) {
        
        if (CVDisplayLinkIsRunning(_cvdl)) {
            CVDisplayLinkStop(_cvdl);
        }
        CVDisplayLinkRelease(_cvdl);
        _cvdl = nil;
    }
    
    if (_cvdl_resize) {
        if (CVDisplayLinkIsRunning(_cvdl_resize)) {
            CVDisplayLinkStop(_cvdl_resize);
        }
        CVDisplayLinkRelease(_cvdl_resize);
        _cvdl_resize = nil;
    }
    
    
    pthread_mutex_destroy(&_mpv.gl_lock);
    
    [_glContext clearDrawable];
    
    mpv_render_context_free(_mpv.render_context);
    _mpv.render_context = nil;
}

- (void)dealloc {
    if (_mpv.render_context) {
        [self destroyMPVRenderContext];
    }
}

- (void)updateSurfaceWithSize:(CGSize)size {
   // CGLUpdateContext(_mpv.cgl_ctx);
    CGLSetCurrentContext(_mpv.cgl_ctx);
    if (_mpv.opengl_fbo.fbo) {
        glDeleteFramebuffers(1, (const GLuint *)&_mpv.opengl_fbo.fbo);
        _mpv.opengl_fbo.fbo = 0;
    }
    if (_mpv.surface_texture) {
        glDeleteTextures(1, &_mpv.surface_texture);
        _mpv.surface_texture = 1;
    }

    IOSurfaceRef surface = CreateTransparentIOSurface(_mpv.opengl_fbo.w,
                                                      _mpv.opengl_fbo.h);
    _mpv.surface_texture = CreateTextureForIOSurface(_mpv.cgl_ctx, surface);
    _mpv.opengl_fbo.fbo = CreateFBOForTexture(_mpv.surface_texture);
    
    int block_for_target = 0;
    mpv_opengl_fbo fbo = _mpv.opengl_fbo;
    mpv_render_param render_params[] = {
        {
            .type = MPV_RENDER_PARAM_OPENGL_FBO,
            .data = &fbo
        },
        {
            .type = MPV_RENDER_PARAM_BLOCK_FOR_TARGET_TIME,
            .data = &block_for_target
        },
        { 0 }
    };

    [CATransaction begin];
    [CATransaction setValue:@YES forKey:kCATransactionDisableActions];

    mpv_render_context_render(_mpv.render_context, render_params);
    CGLFlushDrawable(_mpv.cgl_ctx);

    _layer.bounds = CGRectMake(0, 0, size.width, size.height);
    _layer.contents = (id)CFAutorelease(surface);
    
    [CATransaction commit];
   // [CATransaction flush];
    CGLSetCurrentContext(nil);
}

- (BOOL)wantsUpdateLayer {
    return (_mpv.render_context != nil);
}

- (void)updateLayer {
    BOOL shouldResumeCVDL = NO;
    if (CVDisplayLinkIsRunning(_cvdl)) {
        CVDisplayLinkStop(_cvdl);
        shouldResumeCVDL = YES;
    }
    pthread_mutex_lock(&_mpv.gl_lock);
    
    NSSize size = self.bounds.size;
    NSSize surfaceSize = [self convertSizeToBacking:size];
    _mpv.opengl_fbo.w = surfaceSize.width;
    _mpv.opengl_fbo.h = surfaceSize.height;
    [self updateSurfaceWithSize:size];
    
    pthread_mutex_unlock(&_mpv.gl_lock);
    
    if (shouldResumeCVDL) {
        CVDisplayLinkStart(_cvdl);
    }
        
}

- (void)viewWillStartLiveResize {

    if (_mpv.render_context && !_isIdle) {

        _layer.drawsAsynchronously = YES;
        CVDisplayLinkStop(_cvdl);
        
        CVDisplayLinkStart(_cvdl_resize);

    }
}

- (void)viewDidEndLiveResize {

    if (_mpv.render_context) {
        _layer.drawsAsynchronously = NO;
        
        CVDisplayLinkStop(_cvdl_resize);

        self.needsDisplay = YES;
        if (!_isIdle) {
            CVDisplayLinkStart(_cvdl);
        }
    }
}

- (void)viewDidMoveToWindow {
    [super viewDidMoveToWindow];
    if (self.window) {
        if (!_mpv.render_context) {
            int error;
            if ((error = [self createMPVRenderContext]) != MPV_ERROR_SUCCESS) {
                NSLog(@"Failed to create mpv_render_context. -> %s", mpv_error_string(error));
                return;
            }
            
            pthread_mutexattr_t mattr;
            pthread_mutexattr_init(&mattr);
#if !MAC_OS_X_VERSION_10_14 || \
    MAC_OS_X_VERSION_MIN_REQUIRED < MAC_OS_X_VERSION_10_14
            pthread_mutexattr_setpolicy_np(&mattr, 2);
#else
            pthread_mutexattr_setpolicy_np(&mattr, _PTHREAD_MUTEX_POLICY_FIRSTFIT);
#endif
            pthread_mutex_init(&_mpv.gl_lock, &mattr);
            
            
            CVDisplayLinkCreateWithActiveCGDisplays(&_cvdl);
            CVDisplayLinkSetOutputCallback(_cvdl, &cvdl_playback_cb, &_mpv);
            
            CVDisplayLinkCreateWithActiveCGDisplays(&_cvdl_resize);
            CVDisplayLinkSetOutputCallback(_cvdl_resize, &cvdl_resize_cb, &_mpv);
            
            self.needsDisplay = YES;
        }
    }
}

- (BOOL)isOpaque {
    return YES;
}

- (BOOL)mouseDownCanMoveWindow {
    return YES;
}

#pragma mark - Notifications

- (void)playerWillShutdown:(NSNotification *)n {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    if (_mpv.render_context) {
        [self destroyMPVRenderContext];
    }
}

- (void)didStartPlayback:(NSNotification *)n {
    _isIdle = NO;
    if (self.inLiveResize) {
        return;
    }
    
    self.needsDisplay = YES;

    if (!CVDisplayLinkIsRunning(_cvdl)) {
        CVDisplayLinkStart(_cvdl);
    }
}

- (void)playerDidEnterIdleMode:(NSNotification *)n {
    _isIdle = YES;
    if (CVDisplayLinkIsRunning(_cvdl)) {
        CVDisplayLinkStop(_cvdl);
    }
    if (CVDisplayLinkIsRunning(_cvdl_resize)) {
        CVDisplayLinkStop(_cvdl_resize);
    }
}

#pragma mark - CVDisplayLink Callbacks

__attribute__((hot))
static CVReturn cvdl_playback_cb(
                                 CVDisplayLinkRef CV_NONNULL displayLink,
                                 const CVTimeStamp * CV_NONNULL inNow,
                                 const CVTimeStamp * CV_NONNULL inOutputTime,
                                 CVOptionFlags flagsIn,
                                 CVOptionFlags * CV_NONNULL flagsOut,
                                 void * CV_NULLABLE displayLinkContext ) {
    
    mpv_data *mpv = displayLinkContext;

    if (mpv_render_context_update(mpv->render_context) & MPV_RENDER_UPDATE_FRAME) {
        CGLSetCurrentContext(mpv->cgl_ctx);
        mpv_render_context_render(mpv->render_context, mpv->render_params);
        CGLFlushDrawable(mpv->cgl_ctx);
        __unsafe_unretained CALayer *layer = (__bridge CALayer *)mpv->layer;
        [layer setContentsChanged];
        [CATransaction commit];
    }
    
    return kCVReturnSuccess;
}

__attribute__((hot))
static CVReturn cvdl_resize_cb(
                               CVDisplayLinkRef CV_NONNULL displayLink,
                               const CVTimeStamp * CV_NONNULL inNow,
                               const CVTimeStamp * CV_NONNULL inOutputTime,
                               CVOptionFlags flagsIn,
                               CVOptionFlags * CV_NONNULL flagsOut,
                               void * CV_NULLABLE displayLinkContext ) {
    
    mpv_data *mpv = displayLinkContext;

    pthread_mutex_lock(&mpv->gl_lock);
    
    if (mpv_render_context_update(mpv->render_context) & MPV_RENDER_UPDATE_FRAME) {
        int block_for_target = 0;
        mpv_opengl_fbo fbo = mpv->opengl_fbo;
        mpv_render_param render_params[] = {
            {
                .type = MPV_RENDER_PARAM_OPENGL_FBO,
                .data = &fbo
            },
            {
                .type = MPV_RENDER_PARAM_BLOCK_FOR_TARGET_TIME,
                .data = &block_for_target
            },
            { 0 }
        };
        
        CGLUpdateContext(mpv->cgl_ctx);
        CGLSetCurrentContext(mpv->cgl_ctx);
        
        [CATransaction begin];
        //[CATransaction setValue:@YES forKey:kCATransactionDisableActions];
        mpv_render_context_render(mpv->render_context, render_params);
        CGLFlushDrawable(mpv->cgl_ctx);
        CALayer *layer = (__bridge CALayer *)mpv->layer;
        [layer setContentsChanged];
        
        [CATransaction commit];
       // [CATransaction flush];
    }
    
    pthread_mutex_unlock(&mpv->gl_lock);
    
    return kCVReturnSuccess ;
}

@end
