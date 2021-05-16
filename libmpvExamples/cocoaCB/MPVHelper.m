//
//  MPVHelper.m
//  libmpvExamples
//
//  Created by Terminator on 2019/08/01.
//  Copyright © 2019年 home. All rights reserved.
//

#import "MPVHelper.h"
#import <dlfcn.h>

@import OpenGL.GL;
@import OpenGL.GL3;

extern void *g_opengl_framework_handle;

static void gl_dummy() { }

static void *get_proc_address(void *ctx, const char *symbol) {
    
    if (strcmp(symbol, "glFlush") == 0) {
        return gl_dummy;
    }
    
    return dlsym(g_opengl_framework_handle, symbol);
}

@interface MPVHelper ()

@property (nonatomic) GLint fbo;

@end

@implementation MPVHelper

#pragma mark - Init / Deinit

- (instancetype)initWithMpvHandle:(mpv_handle *)mpv
{
    self = [super init];
    if (self) {
        _mpv_handle = mpv;
        mpv_observe_property(_mpv_handle, 0, "ontop", MPV_FORMAT_FLAG);
        mpv_observe_property(_mpv_handle, 0, "border", MPV_FORMAT_FLAG);
        mpv_observe_property(_mpv_handle, 0, "keepaspect-window", MPV_FORMAT_FLAG);
        mpv_observe_property(_mpv_handle, 0, "macos-title-bar-style", MPV_FORMAT_STRING);
    }
    return self;
}

- (void)initRender {
    
    mpv_opengl_init_params pAddress = {
        .get_proc_address = get_proc_address,
        .get_proc_address_ctx = g_opengl_framework_handle,
        .extra_exts = NULL,
    };
    mpv_render_param params[] = {
        { .type = MPV_RENDER_PARAM_API_TYPE, .data = MPV_RENDER_API_TYPE_OPENGL },
        { .type = MPV_RENDER_PARAM_OPENGL_INIT_PARAMS, .data = &pAddress },
        { 0 }
    };
    if (mpv_render_context_create(&_mpv_render_context, _mpv_handle, params) < 0) {
        NSLog(@"Render context init has failed.");
        exit(EXIT_FAILURE);
    }
}

- (void)deinitRender {
    mpv_render_context_set_update_callback(_mpv_render_context, NULL, NULL);
    mpv_render_context_free(_mpv_render_context);
    _mpv_render_context = NULL;
}

- (void)deinitMPV:(BOOL)destroy {
    if (destroy) {
        mpv_destroy(_mpv_handle);
    }
    _mpv_handle = nil;
}

- (void)setRenderUpdateCallback:(mpv_render_update_fn)callback context:(id)object {
    if (!_mpv_render_context) {
        NSLog(@"Init mpv render context first.");
    } else {
        mpv_render_context_set_update_callback(_mpv_render_context, callback, (__bridge void *)object);
    }
}

#pragma mark - Render

- (void)reportRenderFlip {
    if (_mpv_render_context) {
        mpv_render_context_report_swap(_mpv_render_context);
    }
}

- (void)drawRender:(NSSize)surface {
    if (_mpv_render_context) {
        GLint i = 0;
        int flip = 1;
        glGetIntegerv(GL_DRAW_FRAMEBUFFER_BINDING, &i);
        /* CAOpenGLLayer has ownership of FBO zero yet can return it to us,
         so only utilize a newly received FBO ID if it is nonzero. */
        _fbo = i ? i : _fbo;
        
        mpv_opengl_fbo fbo_data = {
            .fbo = _fbo,
            .w = surface.width,
            .h = surface.height,
            .internal_format = 0
        };
        mpv_render_param params[] = {
            { .type = MPV_RENDER_PARAM_OPENGL_FBO, .data = &fbo_data },
            { .type = MPV_RENDER_PARAM_FLIP_Y, .data = &flip },
            { 0 }
        };
        mpv_render_context_render(_mpv_render_context, params);
    } else {
        glClearColor(0, 0, 0 , 1);
        glClear(GL_COLOR_BUFFER_BIT);
    }
}

#pragma mark - Commands

- (void)command:(NSString *)cmd {
    if (_mpv_handle) {
        mpv_command_string(_mpv_handle, cmd.UTF8String);
    }
}

- (void)commandAsync:(NSArray <NSString *> *)cmd id:(NSUInteger)replyID {
    if (_mpv_handle) {
        size_t size = cmd.count + 1, i = 0;
        char **args = calloc(size, sizeof(char *));
        for (NSString *s in cmd) {
            args[i++] = strdup(s.UTF8String);
        }
        mpv_command_async(_mpv_handle, replyID, (const char **)args);
        char **ptr = args;
        while (*ptr) { free(*ptr++); }
        free(args);
    }
}

#pragma mark - MPV Properties

- (BOOL)getBoolProperty:(NSString *)name {
    if (_mpv_handle) {
        int value = 0;
        mpv_get_property(_mpv_handle, name.UTF8String, MPV_FORMAT_FLAG, &value);
        return (value);
    }
    return NO;
}

- (NSInteger)getIntProperty:(NSString *)name {
    if (_mpv_handle) {
        uint64_t value;
        mpv_get_property(_mpv_handle, name.UTF8String, MPV_FORMAT_INT64, &value);
        return value;
    }
    return 0;
}

- (NSString *)getStringProperty:(NSString *)name {
    if (_mpv_handle) {
        char *str = mpv_get_property_string(_mpv_handle, name.UTF8String);
        if (str) {
            NSString *result = @(str);
            mpv_free(str);
            return result;
        }
    }
    return nil;
}

@end
