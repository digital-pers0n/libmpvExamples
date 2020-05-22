//
//  MPVPlayerView.m
//  libmpvExamples
//
//  Created by Terminator on 2019/08/13.
//  Copyright © 2019年 home. All rights reserved.
//

#import "MPVPlayerView.h"
#import "MPVPlayer.h"
#import <mpv/render_gl.h>
#import <stdatomic.h>
#import <pthread/pthread.h>
#import <pthread/pthread_spis.h>

#import <dlfcn.h>

@import OpenGL.GL;
@import OpenGL.GL3;

extern void *g_opengl_framework_handle;

static GLboolean gl_IsQuery(GLuint id) { return GL_FALSE; }

static void gl_dummy() { }

static void *get_proc_address(void *ctx, const char *symbol) {
    
    if (strcmp(symbol, "glFlush") == 0) {
        return gl_dummy;
    }
    
    if (strcmp(symbol, "glViewport") == 0) {
        return gl_dummy;
    }
    
    if (strcmp(symbol, "glScissor") == 0) {
        return &gl_dummy;
    }

    
    if (strcmp(symbol, "glClearColor") == 0) {
        return &gl_dummy;
    }
    
    if (strcmp(symbol, "glClear") == 0) {
        return &gl_dummy;
    }
    if (strcmp(symbol, "glGetQueryObjectui64v") == 0) {
        return gl_dummy;
    }
    
    if (strcmp(symbol, "glBeginQuery") == 0) {
        return gl_dummy;
    }
    
    if (strcmp(symbol, "glEndQuery") == 0) {
        return gl_dummy;
    }
    
    if (strcmp(symbol, "glEnable") == 0) {
        return gl_dummy;
    }
    
    if (strcmp(symbol, "glDisable") == 0) {
        return gl_dummy;
    }
    
    if (strcmp(symbol, "glIsQuery") == 0) {
        return &gl_IsQuery;
    }
    
//    if (strcmp(symbol, "glBindFramebuffer") == 0) {
//        return gl_dummy;
//    }
    
    return dlsym(g_opengl_framework_handle, symbol);
}

#define threads_num 3

@interface MPVPlayerView () {
    mpv_opengl_fbo _mpv_opengl_fbo;
    mpv_render_param _mpv_render_params[3];
    mpv_render_context *_mpv_render_context;
    MPVPlayer *_player;
    NSOpenGLContext *_glContext;
    struct _CGLContextObject   *_cglContext;
    dispatch_queue_t _mpv_render_queue;

    pthread_t _render_thread[threads_num];
    pthread_cond_t _render_cond;
    pthread_mutex_t _render_mutex;
    bool _done;
}

@end

@implementation MPVPlayerView

- (instancetype)initWithFrame:(NSRect)frame
{
    self = [super initWithFrame:frame];
    if (self) {
        if ([self createOpenGLContext] != 0) {
            NSLog(@"Failed to create OpenGL context.");
            return nil;
        }
        
        if ([self createMPVPlayer] != 0) {
            NSLog(@"Failed to create MPVPlayer instance. -> %@", _player.error.localizedDescription);
            _player = nil;
            _glContext = nil;
            _cglContext = nil;
            return nil;
        }
        
        NSNotificationCenter *nc = [NSNotificationCenter defaultCenter];
        [nc addObserver:self
               selector:@selector(globalFrameDidChange:)
                   name:NSViewGlobalFrameDidChangeNotification
                 object:self];
        
        [nc addObserver:self
               selector:@selector(playerWillShutdown:)
                   name:MPVPlayerWillShutdownNotification
                 object:_player];
        
        dispatch_queue_attr_t attr = dispatch_queue_attr_make_with_qos_class(
                                                                             DISPATCH_QUEUE_SERIAL,
                                                                             QOS_CLASS_USER_INTERACTIVE, 0);
        _mpv_render_queue = dispatch_queue_create("com.playerView.render-queue", attr);
       self.canDrawConcurrently = YES;
        
        NSSize surfaceSize = [self convertRectToBacking:frame].size;
        _mpv_opengl_fbo.w = surfaceSize.width;
        _mpv_opengl_fbo.h = surfaceSize.height;
        
    }
    return self;
}

- (int)createOpenGLContext {
    NSOpenGLPixelFormatAttribute attributes[] = {
        NSOpenGLPFANoRecovery,
        NSOpenGLPFAAllowOfflineRenderers,
        NSOpenGLPFAAccelerated,
        //NSOpenGLPFADoubleBuffer,
        NSOpenGLPFAOpenGLProfile, NSOpenGLProfileVersion3_2Core,
        0
    };
    
    NSOpenGLPixelFormat *openGLPixelFormat = [[NSOpenGLPixelFormat alloc] initWithAttributes:attributes];
    
    if (!openGLPixelFormat) {
        return -1;
    }
    
    NSOpenGLContext *openGLContext = [[NSOpenGLContext alloc] initWithFormat:openGLPixelFormat shareContext:nil];
    
    if (!openGLContext) {
        return -1;
    }
    
    GLint swapInt = 1;
    [openGLContext setValues:&swapInt forParameter:NSOpenGLCPSwapInterval];
    
    _glContext = openGLContext;
    _cglContext = openGLContext.CGLContextObj;
    
    return 0;
}

- (int)createMPVPlayer {
    _player = MPVPlayer.new;
    if (_player.status == MPVPlayerStatusFailed) {
        return -1;
    }
    return 0;
}

- (int)createMPVRenderContext {
    
    _glContext.view = self;
    [_glContext makeCurrentContext];
    
    glDisable (GL_ALPHA_TEST);
    glDisable (GL_DEPTH_TEST);
    //glDisable (GL_SCISSOR_TEST);
    //glDisable (GL_BLEND);
    glEnable (GL_SCISSOR_TEST);
    glEnable (GL_BLEND);
    glDisable (GL_DITHER);
    glDisable (GL_CULL_FACE);
    glDisable (GL_MULTISAMPLE);
    glDisable (GL_FOG);
    glDisable (GL_TEXTURE_1D);
    glDisable (GL_TEXTURE_3D);
    glDisable (GL_TEXTURE_2D);
    glDisable (GL_LIGHTING);
    //glDisable (GL_VIEWPORT);
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

    _mpv_render_params[0] = (mpv_render_param) { .type = MPV_RENDER_PARAM_OPENGL_FBO, .data = &_mpv_opengl_fbo };
    _mpv_render_params[1] = (mpv_render_param) { .type = MPV_RENDER_PARAM_FLIP_Y,     .data = &mpv_flip_y };
    _mpv_render_params[2] = (mpv_render_param) { 0 };
    
    mpv_opengl_init_params mpv_opengl_init_params = { .get_proc_address = get_proc_address,
        .get_proc_address_ctx = g_opengl_framework_handle};
    mpv_render_param params[] = {
        { .type = MPV_RENDER_PARAM_API_TYPE,           .data = MPV_RENDER_API_TYPE_OPENGL },
        { .type = MPV_RENDER_PARAM_OPENGL_INIT_PARAMS, .data = &mpv_opengl_init_params },
        { 0 }
    };

    return mpv_render_context_create(&_mpv_render_context, _player.mpv_handle, params);
}

- (void)destroyMPVRenderContext {
    mpv_render_context_set_update_callback(_mpv_render_context, NULL, NULL);
    [_glContext clearDrawable];
    
    _done = true;
    pthread_cond_broadcast(&_render_cond);

    for (int i = 0; i < threads_num; i++) {
        pthread_join(_render_thread[i], NULL);
    }

    pthread_mutex_destroy(&_render_mutex);
    pthread_cond_destroy(&_render_cond);
    
    mpv_render_context_free(_mpv_render_context);
    _mpv_render_context = NULL;
}

#pragma mark - Overrides

- (void)lockFocus {
    [super lockFocus];
    _glContext.view = self;
}

- (void)setFrame:(NSRect)frame {
    [super setFrame:frame];
    pthread_mutex_lock(&_render_mutex);
    NSSize size = [self convertSizeToBacking:frame.size];
    _mpv_opengl_fbo.w = size.width;
    _mpv_opengl_fbo.h = size.height;
    pthread_mutex_unlock(&_render_mutex);
}

- (void)viewWillStartLiveResize {
    [super viewWillStartLiveResize];
    if (_mpv_render_context) {
        mpv_render_context_set_update_callback(_mpv_render_context, render_resize_callback, (__bridge void *)self );
        self.needsDisplay = YES;
    }
}

- (void)viewDidEndLiveResize {
    [super viewDidEndLiveResize];
    if (_mpv_render_context) {
        self.needsDisplay = YES;
        mpv_render_context_set_update_callback(_mpv_render_context, render_context_callback, (__bridge void *)self );
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

- (void)drawRect:(NSRect)dirtyRect {
    if (_mpv_render_context) {
        
        pthread_mutex_lock(&_render_mutex);
        render_resize(self);
        pthread_mutex_unlock(&_render_mutex);

    } else {
        CGLSetCurrentContext(_cglContext);
        glClearColor(0, 0, 0, 1);
        glClear(GL_COLOR_BUFFER_BIT);
        glFlush();
    }
}

- (void)viewDidMoveToWindow {
    if (!_mpv_render_context && self.window) {
        int error = [self createMPVRenderContext];
        if (error != MPV_ERROR_SUCCESS) {
            NSLog(@"Failed to create mpv_render_context. -> %s", mpv_error_string(error));
            return;
        }
        pthread_condattr_t condattr;
        pthread_condattr_init(&condattr);
        pthread_cond_init(&_render_cond, &condattr);
        
        pthread_mutexattr_t mattr;
        pthread_mutexattr_init(&mattr);

#if !MAC_OS_X_VERSION_10_14 || \
    MAC_OS_X_VERSION_MIN_REQUIRED < MAC_OS_X_VERSION_10_14
        // _PTHREAD_MUTEX_POLICY_FIRSTFIT 2
        pthread_mutexattr_setpolicy_np(&mattr, 2); // https://blog.mozilla.org/nfroyd/2017/03/29/on-mutex-performance-part-1/
#else
        pthread_mutexattr_setpolicy_np(&mattr, _PTHREAD_MUTEX_POLICY_FIRSTFIT);
#endif
        pthread_mutex_init(&_render_mutex, &mattr) ;
        
        pthread_attr_t attrs;
        pthread_attr_init(&attrs);
        pthread_attr_set_qos_class_np(&attrs, QOS_CLASS_USER_INTERACTIVE, 0);
        for (int i = 0; i < threads_num; i++) {
            pthread_create(_render_thread + i, &attrs, &_render_frame, (__bridge void *)self);
        }
        
        pthread_condattr_destroy(&condattr);
        pthread_attr_destroy(&attrs);
        pthread_mutexattr_destroy(&mattr);
        
        NSSize surfaceSize = [self convertRectToBacking:self.frame].size;
        _mpv_opengl_fbo.w = surfaceSize.width;
        _mpv_opengl_fbo.h = surfaceSize.height;
        
        mpv_render_context_set_update_callback(_mpv_render_context, render_context_callback, (__bridge void *)self);
    }
}

- (void)dealloc {
    if (_mpv_render_context) {
        [self destroyMPVRenderContext];
    }
}

#pragma mark - Properties

- (BOOL)isReadyForDisplay {
    return (_mpv_render_context && _player && _player.status == MPVPlayerStatusReadyToPlay);
}

#pragma mark - Notifications

- (void)globalFrameDidChange:(NSNotification *)n {
    pthread_mutex_lock(&_render_mutex);
    [_glContext update];
    pthread_mutex_unlock(&_render_mutex);
}

- (void)playerWillShutdown:(NSNotification *)n {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    if (_mpv_render_context) {
        [self destroyMPVRenderContext];
    }
}

#pragma mark - functions

static void reshape_context(__unsafe_unretained MPVPlayerView *obj) {
    NSRect glRect = [obj convertRectToBacking:obj.bounds];
    obj->_mpv_opengl_fbo.w = NSWidth(glRect);
    obj->_mpv_opengl_fbo.h = NSHeight(glRect);
}

static void *_render_frame(void *ctx) {
    pthread_setname_np("render thread");
    __unsafe_unretained MPVPlayerView *obj = (__bridge id)ctx;
    
    while (obj->_done == false) {
        pthread_mutex_lock(&obj->_render_mutex);
        
        pthread_cond_wait(&obj->_render_cond, &(obj->_render_mutex));
        
        render_frame(obj);
        
        pthread_mutex_unlock(&obj->_render_mutex);
    }
    
    pthread_exit(NULL);
    return NULL;
}

#pragma mark - mpv_render_context callbacks

static void render_frame(__unsafe_unretained MPVPlayerView *obj) {
    CGLSetCurrentContext(obj->_cglContext);
    mpv_render_context_render(obj->_mpv_render_context, obj->_mpv_render_params);
    glFlush();
}

static void render_context_callback(void *ctx) {
    MPVPlayerView *obj = (__bridge id)ctx;
    pthread_cond_signal(&obj->_render_cond);
}

static void render_resize(__unsafe_unretained MPVPlayerView *obj) {
    CGLSetCurrentContext(obj->_cglContext);
    CGLUpdateContext(obj->_cglContext);
    
    mpv_opengl_fbo fbo = obj->_mpv_opengl_fbo;
    int block_for_target = 0;
    int flip_y = 1;
    
    mpv_render_param render_params[] = {
        {
            .type = MPV_RENDER_PARAM_OPENGL_FBO,
            .data = &fbo
        },
        {
            .type = MPV_RENDER_PARAM_FLIP_Y,
            .data = &flip_y
        },
        {
            .type = MPV_RENDER_PARAM_BLOCK_FOR_TARGET_TIME,
            .data = &block_for_target
        },
        { 0 }
    };
    glViewport(0, 0, fbo.w, fbo.h);
    glClearColor(0, 0, 0, 1);
    glClear(GL_COLOR_BUFFER_BIT);
    mpv_render_context_render(obj->_mpv_render_context, render_params);
    
    glFlush();
}

static void render_live_resize(__unsafe_unretained MPVPlayerView * obj) {
    pthread_mutex_lock(&obj->_render_mutex);
    if (mpv_render_context_update(obj->_mpv_render_context) &
        MPV_RENDER_UPDATE_FRAME)
    {
        render_resize(obj);
    }
    pthread_mutex_unlock(&obj->_render_mutex);
}

__unused static inline void render_resize_async(__unsafe_unretained MPVPlayerView *obj) {
   dispatch_async_f(obj->_mpv_render_queue,
                    (__bridge void *)obj,
                    (dispatch_function_t)render_live_resize);
}

static void render_resize_callback(void *ctx) {
    MPVPlayerView *obj = (__bridge id)ctx;
    dispatch_async_f(obj->_mpv_render_queue, ctx, (dispatch_function_t)render_resize);
}

@end
