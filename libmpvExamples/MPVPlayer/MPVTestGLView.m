//
//  MPVTestGLView.m
//  libmpvExamples
//
//  Created by Terminator on 2019/12/21.
//  Copyright © 2019年 home. All rights reserved.
//

#import "MPVTestGLView.h"
#import <QuartzCore/QuartzCore.h>
#include <IOKit/graphics/IOGraphicsLib.h>
#import "MPVPlayer.h"
#import <mpv/render_gl.h>
#import <pthread/pthread.h>
#import <pthread/pthread_spis.h>

#import <dlfcn.h>           //    dlsym()

@import OpenGL.GL;
@import OpenGL.GL3;

extern void *g_opengl_framework_handle;

typedef struct mpv_data_ {
    mpv_render_context          *render_context;
    mpv_render_param            render_params[3];
    mpv_opengl_fbo              opengl_fbo;
    struct _CGLContextObject    *cgl_ctx;
    pthread_mutex_t             gl_lock;
} mpv_data;

@interface MPVTestGLView () <MPVPropertyObserving> {
    
    NSOpenGLContext *_glContext;
    struct _CGLContextObject *_cglContext;
    dispatch_queue_t _main_queue;
    
    CVDisplayLinkRef _cvdl;
    CVDisplayLinkRef _cvdl_resize;
    mpv_data _mpv;
    
    BOOL _isIdle;
}



@end

@implementation MPVTestGLView

#pragma mark - Initialization

- (instancetype)initWithFrame:(NSRect)frame
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
            _player = nil;
            return nil;
        }
        
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

        
        _main_queue = dispatch_get_main_queue();
        _glContext = self.openGLContext;
        _cglContext = _glContext.CGLContextObj;
        _mpv.cgl_ctx = _cglContext;
        
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
    
    glDisable (GL_ALPHA_TEST);
    glDisable (GL_DEPTH_TEST);
    glDisable (GL_DITHER);
    glDisable (GL_CULL_FACE);
    glDisable (GL_MULTISAMPLE);
    glDisable (GL_FOG);
    glDisable (GL_TEXTURE_1D);
    glDisable (GL_TEXTURE_3D);
    glDisable (GL_TEXTURE_2D);
    glDisable (GL_LIGHTING);
    glDisable (GL_POINT_SMOOTH);
    
    glColorMask (GL_TRUE, GL_TRUE, GL_TRUE, GL_FALSE);
    glDepthMask (GL_FALSE);
    glStencilMask (0);
    glHint (GL_TRANSFORM_HINT_APPLE, GL_FASTEST);
    glHint (GL_VERTEX_ARRAY_STORAGE_HINT_APPLE, GL_FASTEST);
    glHint (GL_TEXTURE_STORAGE_HINT_APPLE, GL_FASTEST);
    glHint (GL_FRAGMENT_SHADER_DERIVATIVE_HINT_ARB, GL_FASTEST);
    glHint (GL_TEXTURE_COMPRESSION_HINT_ARB , GL_FASTEST);
    glHint (GL_MULTISAMPLE_FILTER_HINT_NV, GL_FASTEST);
    glHint (GL_GENERATE_MIPMAP_HINT_SGIS, GL_FASTEST);
    
    [_glContext update];
    
    static int mpv_flip_y = 1;
    
    _mpv.render_params[0] = (mpv_render_param) { .type = MPV_RENDER_PARAM_OPENGL_FBO, .data = &_mpv.opengl_fbo };
    _mpv.render_params[1] = (mpv_render_param) { .type = MPV_RENDER_PARAM_FLIP_Y,     .data = &mpv_flip_y };
    _mpv.render_params[2] = (mpv_render_param) { 0 };
    
    mpv_opengl_init_params mpv_opengl_init_params = {
        .get_proc_address = &dlsym,
        .get_proc_address_ctx = g_opengl_framework_handle
    };
    
    int flag = 1;
    mpv_render_param params[] = {
        { .type = MPV_RENDER_PARAM_API_TYPE,           .data = MPV_RENDER_API_TYPE_OPENGL },
        { .type = MPV_RENDER_PARAM_OPENGL_INIT_PARAMS, .data = &mpv_opengl_init_params },
        { .type = MPV_RENDER_PARAM_ADVANCED_CONTROL,   .data = &flag },
        { 0 }
    };
    
    _mpv.opengl_fbo.internal_format = GL_RGBA16F;
    
    return mpv_render_context_create(&_mpv.render_context, _player.mpv_handle, params);
}

- (void)destroyMPVRenderContext {
    if (_cvdl) {
    
        if (!CVDisplayLinkIsRunning(_cvdl)) {
            CVDisplayLinkStop(_cvdl);
        }
        CVDisplayLinkRelease(_cvdl);
        _cvdl = nil;
    }
    
    if (_cvdl_resize) {
        if (!CVDisplayLinkIsRunning(_cvdl_resize)) {
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

#pragma mark - Overrides

- (void)player:(MPVPlayer *)player didChangeValue:(id)value forProperty:(NSString *)property format:(mpv_format)format {
    
}

- (void)reshape {
     if (self.inLiveResize) { return; }
    NSSize  surfaceSize = [self convertRectToBacking:self.bounds].size;
    pthread_mutex_lock(&_mpv.gl_lock);
    _mpv.opengl_fbo.w = surfaceSize.width;
    _mpv.opengl_fbo.h = surfaceSize.height;
    pthread_mutex_unlock(&_mpv.gl_lock);
}

- (void)update {
    CGLUpdateContext(_mpv.cgl_ctx);
}

- (void)viewWillStartLiveResize {
    if (_isIdle) {
        return;
    }
    if (_mpv.render_context) {
        
        CVDisplayLinkStop(_cvdl);
        CVDisplayLinkStart(_cvdl_resize);

        self.canDrawConcurrently = YES;
        [self reshape];
        [self update];
    }
}

- (void)viewDidEndLiveResize {
    if (_isIdle) {
        return;
    }
    if (_mpv.render_context) {

        CFRunLoopPerformBlock(CFRunLoopGetMain(), kCFRunLoopCommonModes, ^{
            CVDisplayLinkStop(_cvdl_resize); // this can cause a deadlock
            CVDisplayLinkStart(_cvdl);
        });
        
        self.canDrawConcurrently = NO;
        [self reshape];
        [self update];
    }
}

- (void)drawRect:(NSRect)dirtyRect {

    if (_mpv.render_context) {
        
        pthread_mutex_lock(&_mpv.gl_lock);
        
        NSSize  surfaceSize = [self convertRectToBacking:dirtyRect].size;
        _mpv.opengl_fbo.w = surfaceSize.width;
        _mpv.opengl_fbo.h = surfaceSize.height;
        
        BOOL shouldRestartCVDL = NO;
        if (CVDisplayLinkIsRunning(_cvdl)) {
            CVDisplayLinkStop(_cvdl);
            shouldRestartCVDL = YES;
        }
        
        CGLSetCurrentContext(_mpv.cgl_ctx);
        mpv_render_context_render(_mpv.render_context, _mpv.render_params);
        glFlush();
        
        if (shouldRestartCVDL) {
            CVDisplayLinkStart(_cvdl);
        }
        
        pthread_mutex_unlock(&_mpv.gl_lock);
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
            pthread_mutexattr_setpolicy_np(&mattr, _PTHREAD_MUTEX_POLICY_FIRSTFIT); // https://blog.mozilla.org/nfroyd/2017/03/29/on-mutex-performance-part-1/
            pthread_mutex_init(&_mpv.gl_lock, &mattr);
            
            CVDisplayLinkCreateWithActiveCGDisplays(&_cvdl);
            CVDisplayLinkSetOutputCallback(_cvdl, &cvdl_playback_cb, &_mpv);
            
            CVDisplayLinkCreateWithActiveCGDisplays(&_cvdl_resize);
            CVDisplayLinkSetOutputCallback(_cvdl_resize, &cvdl_resize_cb, (__bridge void *)self);
            
            NSSize  surfaceSize = [self convertRectToBacking:self.bounds].size;
            _mpv.opengl_fbo.w = surfaceSize.width;
            _mpv.opengl_fbo.h = surfaceSize.height;
            
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
CVReturn cvdl_playback_cb(
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
        glFlush();
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
    
    __unsafe_unretained MPVTestGLView *v = (__bridge typeof(v))displayLinkContext;
    
    /* 
       Redraw window's view hierachy.
       At least on macOS 10.11 this produces smoothest live resize possible, 
       without any glitches or choppiness at all, it's even better than CAOpenGLLayer. Needs more tests.
     */
    [v.window display];
    
    /*
     mpv_data *mpv = displayLinkContext;
     
     pthread_mutex_lock(&mpv->gl_lock);
     if (mpv_render_context_update(mpv->render_context) & MPV_RENDER_UPDATE_FRAME) {
     
     CGLSetCurrentContext(mpv->cgl_ctx);
     mpv_render_context_render(mpv->render_context, mpv->render_params);
     glFlush();
     
     }
     pthread_mutex_unlock(&mpv->gl_lock);
     */
    
    return kCVReturnSuccess ;
}


@end

