//
//  MPVPlayerLayer.m
//  libmpvExamples
//
//  Created by Terminator on 2019/08/27.
//  Copyright © 2019年 home. All rights reserved.
//

#import "MPVPlayerLayer.h"

#import "MPVPlayer.h"
#import <mpv/render_gl.h>

#import <dlfcn.h>           //    dlsym()

@import OpenGL.GL;
@import OpenGL.GL3;

extern void *g_opengl_framework_handle;

@interface MPVPlayerLayer () {
    mpv_render_context *_mpv_render_context;
    mpv_opengl_fbo _mpv_opengl_fbo;
    mpv_render_param _mpv_render_params[3];
    CGLContextObj _cglContext;
    CGLPixelFormatObj _cglPixelFormat;
    dispatch_queue_t _mpv_render_queue;
    dispatch_queue_t _main_queue;
    dispatch_group_t _dispatch_group;
}

@end

@implementation MPVPlayerLayer

- (instancetype)init
{
    self = [super init];
    if (self) {
        _cglPixelFormat = [self copyCGLPixelFormatForDisplayMask:0];
        if (!_cglPixelFormat) {
            NSLog(@"Failed to create CGLPixelFormatObj");
            return nil;
        }
        CGLError err = CGLCreateContext(_cglPixelFormat, nil, &_cglContext);
        if (!_cglContext) {
            NSLog(@"Failed to create CGLContextObj %d", err);
            return nil;
        }
        GLint i = 1;
        CGLSetParameter(_cglContext, kCGLCPSwapInterval, &i);
        
        if ([self createMPVPlayer] != 0) {
            NSLog(@"Failed to create MPVPlayer instance -> %@", _player.error.localizedDescription);
            return nil;
        }
        
        dispatch_queue_attr_t attr = dispatch_queue_attr_make_with_qos_class(
                                                                             DISPATCH_QUEUE_SERIAL,
                                                                             QOS_CLASS_USER_INTERACTIVE, 0);
        _mpv_render_queue = dispatch_queue_create("com.home.mpvPlayerLayer.render-queue", attr);
        _main_queue = dispatch_get_main_queue();
        
        __block int error = 0;
        dispatch_sync(_mpv_render_queue, ^{
            error = [self createMPVRenderContext];
        });
        
        if (error != MPV_ERROR_SUCCESS) {
            NSLog(@"Failed to create mpv_render_context -> %s", mpv_error_string(error));
            return nil;
        }
        
        NSNotificationCenter *nc = [NSNotificationCenter defaultCenter];
        [nc addObserver:self
               selector:@selector(playerWillShutdown:)
                   name:MPVPlayerWillShutdownNotification
                 object:_player];
        
        mpv_render_context_set_update_callback(_mpv_render_context, render_context_callback, (__bridge void *)self);
    }
    return self;
}

- (int)createMPVPlayer {
    _player = MPVPlayer.new;
    if (_player.status == MPVPlayerStatusFailed) {
        return -1;
    }
    return 0;
}

- (CGLPixelFormatObj)copyCGLPixelFormatForDisplayMask:(uint32_t)mask {
    CGLPixelFormatAttribute glAttributes[] = {
        kCGLPFAOpenGLProfile,  (CGLPixelFormatAttribute)kCGLOGLPVersion_3_2_Core,
        kCGLPFAAccelerated,
        kCGLPFADoubleBuffer,
        kCGLPFAAllowOfflineRenderers,
        kCGLPFASupportsAutomaticGraphicsSwitching,
        0
    };
    CGLPixelFormatObj pix;
    GLint npix = 0;
    CGLError error = CGLChoosePixelFormat(glAttributes, &pix, &npix);
    if (error != kCGLNoError) {
        return nil;
    }
    return pix;
}

- (int)createMPVRenderContext {
    static int mpv_flip_y = 1;
    
    _mpv_opengl_fbo = (mpv_opengl_fbo) { .fbo = 1, .w = NSWidth(self.bounds), .h = NSHeight(self.bounds) };
    _mpv_render_params[0] = (mpv_render_param) { .type = MPV_RENDER_PARAM_OPENGL_FBO, .data = &_mpv_opengl_fbo };
    _mpv_render_params[1] = (mpv_render_param) { .type = MPV_RENDER_PARAM_FLIP_Y,     .data = &mpv_flip_y };
    _mpv_render_params[2] = (mpv_render_param) { 0 };
    
    mpv_opengl_init_params mpv_opengl_init_params = {
        .get_proc_address = dlsym,
        .get_proc_address_ctx = g_opengl_framework_handle
    };
    
    mpv_render_param params[] = {
        { .type = MPV_RENDER_PARAM_API_TYPE,           .data = MPV_RENDER_API_TYPE_OPENGL },
        { .type = MPV_RENDER_PARAM_OPENGL_INIT_PARAMS, .data = &mpv_opengl_init_params },
        { 0 }
    };
    CGLSetCurrentContext(_cglContext);
    return mpv_render_context_create(&_mpv_render_context, _player.mpv_handle, params);
}

- (void)destroyMPVRenderContext {
    mpv_render_context_set_update_callback(_mpv_render_context, NULL, NULL);
    dispatch_sync(_mpv_render_queue, ^{
        CGLClearDrawable(_cglContext);
        mpv_render_context_free(_mpv_render_context);
        _mpv_render_context = NULL;
    });
}

- (void)dealloc {
    if (_mpv_render_context) {
        [self destroyMPVRenderContext];
    }
}

#pragma mark - Overrides

- (BOOL)canDrawInCGLContext:(CGLContextObj)ctx pixelFormat:(CGLPixelFormatObj)pf forLayerTime:(CFTimeInterval)t displayTime:(const CVTimeStamp *)ts {
    return (_mpv_render_context != nil);
}

- (void)drawInCGLContext:(CGLContextObj)ctx pixelFormat:(CGLPixelFormatObj)pf forLayerTime:(CFTimeInterval)t displayTime:(const CVTimeStamp *)ts {
    _draw_frame(self);
}

- (CGLContextObj)copyCGLContextForPixelFormat:(CGLPixelFormatObj)pf {
    return _cglContext;
}

#pragma mark - Notifications

- (void)playerWillShutdown:(NSNotification *)n {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    if (_mpv_render_context) {
        [self destroyMPVRenderContext];
    }
}

#pragma mark - mpv_render_context callbacks

static inline void _draw_frame(MPVPlayerLayer *obj) {
    
    static GLint dims[] = { 0, 0, 0, 0 };
    glGetIntegerv(GL_VIEWPORT, dims);
    GLint width = dims[2];
    GLint height = dims[3];
    if (width == 0 || height == 0) {
        NSSize surfaceSize = obj.bounds.size;;
        width = surfaceSize.width * obj.contentsScale;
        height = surfaceSize.height * obj.contentsScale;
    }
    obj->_mpv_opengl_fbo.w = width;
    obj->_mpv_opengl_fbo.h = height;
    
    GLint i = 0;
    glGetIntegerv(GL_DRAW_FRAMEBUFFER_BINDING, &i);

    if (i) {
        obj->_mpv_opengl_fbo.fbo = i;
    }

    mpv_render_context_render(obj->_mpv_render_context, obj->_mpv_render_params);
    
    CGLFlushDrawable(obj->_cglContext);
}

static void _render(void *ctx) {
    
    __unsafe_unretained MPVPlayerLayer *obj = (__bridge id)ctx;
    [obj display];
    [CATransaction flush];
}

static void render_context_callback(void *ctx) {
    MPVPlayerLayer *obj = (__bridge id)ctx;
    dispatch_async_f(obj->_mpv_render_queue, ctx, _render);
}

@end
