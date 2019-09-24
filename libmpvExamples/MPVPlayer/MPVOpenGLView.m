//
//  MPVOpenGLView.m
//  libmpvExamples
//
//  Created by Terminator on 2019/08/27.
//  Copyright © 2019年 home. All rights reserved.
//

#import "MPVOpenGLView.h"
#import "MPVPlayer.h"
#import <mpv/render_gl.h>
#import <pthread/pthread.h>

#import <dlfcn.h>           //    dlsym()

@import OpenGL.GL;
@import OpenGL.GL3;

extern void *g_opengl_framework_handle;

@interface MPVOpenGLView () {
    
    mpv_render_context *_mpv_render_context;
    mpv_opengl_fbo _mpv_opengl_fbo;
    mpv_render_param _mpv_render_params[3];
    
    NSOpenGLContext *_glContext;
    struct _CGLContextObject *_cglContext;
    
    dispatch_queue_t _main_queue;
    dispatch_queue_t _render_queue;
    dispatch_source_t _dispatch_source;
}

@end

@implementation MPVOpenGLView

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
        
        _main_queue = dispatch_get_main_queue();
        _glContext = self.openGLContext;
        _cglContext = _glContext.CGLContextObj;
        
        dispatch_queue_attr_t attr = dispatch_queue_attr_make_with_qos_class(
                                                                             DISPATCH_QUEUE_SERIAL,
                                                                             QOS_CLASS_USER_INTERACTIVE, 0);
        _render_queue = dispatch_queue_create("com.home.openGLView.render-queue", attr);

        _dispatch_source = dispatch_source_create(DISPATCH_SOURCE_TYPE_DATA_OR, 0, 0, _render_queue);
        dispatch_source_set_event_handler_f(_dispatch_source, (void *)_render);
        dispatch_set_context(_dispatch_source, (__bridge void *)self);
        dispatch_resume(_dispatch_source);
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
    
    static int mpv_flip_y = 1;

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
    
    return mpv_render_context_create(&_mpv_render_context, _player.mpv_handle, params);
}

- (void)destroyMPVRenderContext {
    [_glContext clearDrawable];
    mpv_render_context_set_update_callback(_mpv_render_context, NULL, NULL);
    dispatch_source_cancel(_dispatch_source);
    mpv_render_context_free(_mpv_render_context);
    _mpv_render_context = NULL;
    
}

- (void)dealloc {
    if (_mpv_render_context) {
        [self destroyMPVRenderContext];
    }
}

#pragma mark - Overrides

- (void)reshape {
    if (self.inLiveResize) { return; }
    CGLLockContext(_cglContext);
    {
        GLint dims[] = { 0, 0, 0, 0 };
        glGetIntegerv(GL_VIEWPORT, dims);
        NSSize surfaceSize = NSMakeSize(dims[2], dims[3]);
        if (NSEqualSizes(surfaceSize, NSZeroSize)) {
            surfaceSize = [self convertRectToBacking:self.bounds].size;
        }
        _mpv_opengl_fbo.w = surfaceSize.width;
        _mpv_opengl_fbo.h = surfaceSize.height;
    }
    CGLUnlockContext(_cglContext);
}

- (void)update {
   if (self.inLiveResize) { return; }
    [_glContext update];
}

- (void)viewWillStartLiveResize {

    if (_mpv_render_context) {
        self.wantsLayer = YES;
        self.layer.drawsAsynchronously = YES;
        mpv_render_context_set_update_callback(_mpv_render_context, render_live_resize_callback, (__bridge void *)self );
    }
}

- (void)viewDidEndLiveResize {
    if (_mpv_render_context) {
        self.layer.drawsAsynchronously = NO;
        self.wantsLayer = NO;
        mpv_render_context_set_update_callback(_mpv_render_context, render_context_callback, (__bridge void *)self );
        [_glContext makeCurrentContext];
        [_glContext update];
        NSRect bounds = self.bounds;
        _mpv_opengl_fbo.w = NSWidth(bounds);
        _mpv_opengl_fbo.h = NSHeight(bounds);
    }
}

- (void)drawRect:(NSRect)dirtyRect {
    if (_mpv_render_context) {
        {
            mpv_render_context_render(_mpv_render_context, _mpv_render_params);
            CGLFlushDrawable(_cglContext);
        }
    }
}

- (void)viewDidMoveToWindow {
    [super viewDidMoveToWindow];
    if (self.window) {
        if (!_mpv_render_context) {
            int error;
            if ((error = [self createMPVRenderContext]) != MPV_ERROR_SUCCESS) {
                NSLog(@"Failed to create mpv_render_context. -> %s", mpv_error_string(error));
                return;
            }

            mpv_render_context_set_update_callback(_mpv_render_context, render_context_callback, (__bridge void *)self);
            
        }
    }
}

#pragma mark - Notifications

- (void)playerWillShutdown:(NSNotification *)n {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    if (_mpv_render_context) {
        [self destroyMPVRenderContext];
    }
}

#pragma mark - mpv_render_context callbacks

static void _render(void *ctx) {
    __unsafe_unretained MPVOpenGLView *obj = (__bridge id)ctx;
    CGLSetCurrentContext(obj->_cglContext);
    mpv_render_context_render(obj->_mpv_render_context, obj->_mpv_render_params);
    CGLFlushDrawable(obj->_cglContext);
}

static void render_context_callback(void *ctx) {
    MPVOpenGLView *obj = (__bridge id)ctx;
    dispatch_source_merge_data(obj->_dispatch_source, 1);
}

static void _live_resize(MPVOpenGLView *obj) {
    [obj setNeedsDisplay:YES];
}

static void render_live_resize_callback(void *ctx) {
    MPVOpenGLView *obj = (__bridge id)ctx;
    dispatch_async_f(obj->_main_queue, ctx, (void *)_live_resize);
}

@end
