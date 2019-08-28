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
    
    dispatch_queue_t _mpv_render_context_update_queue;
    dispatch_queue_t _mpv_render_live_resize_queue;
    dispatch_queue_t _main_queue;
    dispatch_group_t _dispatch_group;
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
        
        dispatch_queue_attr_t attr = dispatch_queue_attr_make_with_qos_class(
                                                                             DISPATCH_QUEUE_SERIAL,
                                                                             QOS_CLASS_USER_INTERACTIVE, 0);
        _mpv_render_context_update_queue = dispatch_queue_create("com.mpv_render_context.queue", attr);
        
        attr = dispatch_queue_attr_make_with_qos_class(
                                                       DISPATCH_QUEUE_SERIAL,
                                                       QOS_CLASS_USER_INTERACTIVE, 0);
        _mpv_render_live_resize_queue = dispatch_queue_create("com.mpv_live_resize.queue", attr);
        
        
        _main_queue = dispatch_get_main_queue();
        _dispatch_group = dispatch_group_create();
        _glContext = self.openGLContext;
        _cglContext = _glContext.CGLContextObj;
        
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
    dispatch_group_wait(_dispatch_group, dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1 * NSEC_PER_SEC)));
    mpv_render_context_free(_mpv_render_context);
    _mpv_render_context = NULL;
    
}

#pragma mark - Overrides

- (void)setFrame:(NSRect)frame {
    [super setFrame:frame];
    _mpv_opengl_fbo.w = NSWidth(frame);
    _mpv_opengl_fbo.h = NSHeight(frame);
}

- (void)viewWillStartLiveResize {

    if (_mpv_render_context) {
        self.wantsLayer = YES;
        self.layer.drawsAsynchronously = YES;
        dispatch_async(_mpv_render_live_resize_queue, ^{
            mpv_render_context_set_update_callback(_mpv_render_context, render_live_resize_callback, (__bridge void *)self );
        });
    }
}

- (void)viewDidEndLiveResize {
    if (_mpv_render_context) {
        self.layer.drawsAsynchronously = NO;
        self.wantsLayer = NO;
        dispatch_async(_mpv_render_context_update_queue, ^{
            mpv_render_context_set_update_callback(_mpv_render_context, render_context_callback, (__bridge void *)self );
        });
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
            NSRect bounds = self.bounds;
            _mpv_opengl_fbo.w = NSWidth(bounds);
            _mpv_opengl_fbo.h = NSHeight(bounds);
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
            dispatch_async(_mpv_render_context_update_queue, ^{
                mpv_render_context_set_update_callback(_mpv_render_context, render_context_callback, (__bridge void *)self );
            });
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

static void _render(MPVOpenGLView *obj) {
    mpv_render_context_render(obj->_mpv_render_context, obj->_mpv_render_params);
    CGLFlushDrawable(obj->_cglContext);
}

static void render_context_callback(void *ctx) {
    MPVOpenGLView *obj = (__bridge id)ctx;
    dispatch_group_async_f(obj->_dispatch_group, obj->_main_queue, ctx, (void *)_render);
}

static void _live_resize(MPVOpenGLView *obj) {
    [obj setNeedsDisplay:YES];
}

static void render_live_resize_callback(void *ctx) {
    MPVOpenGLView *obj = (__bridge id)ctx;
    dispatch_group_async_f(obj->_dispatch_group, obj->_main_queue, ctx, (void *)_live_resize);
}

@end