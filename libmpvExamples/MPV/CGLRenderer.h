//
//  CGLRenderer.h
//  libmpvExamples
//
//  Created by Terminator on 2021/6/26.
//  Copyright © 2021年 home. All rights reserved.
//

#ifndef CGLRenderer_h
#define CGLRenderer_h

#import "Renderer.h"

#import <dlfcn.h>
#import <mpv/render_gl.h>
#import <OpenGL/gl3.h>

namespace MPV {
struct CGLRenderer : public Renderer {
    static void *GetOpenGLFrameworkHandle() noexcept {
        constexpr auto funcName = __PRETTY_FUNCTION__;
        static void *handle{};
        static dispatch_once_t onceToken{};
        dispatch_once(&onceToken, ^{
            // Try to load OpenGL framework directly.
            // Apple has been reorganizing system directories since macOS 10.15
            // so this may fail in the future.
            if ((handle = dlopen("/System/Library/Frameworks/OpenGL.framework"
                                 "/OpenGL", RTLD_LAZY | RTLD_LOCAL))) {
                return;
            }
            
            // Try to find OpenGL framework by its bundle id
            auto path = [NSBundle bundleWithIdentifier:@"com.apple.opengl"]
                         .executablePath.UTF8String;
            if (!path) {
                NSLog(@"[%s] OpenGL framework is not available.", funcName);
                return;
            }
            
            if (!(handle = dlopen(path, RTLD_LAZY | RTLD_LOCAL))) {
                NSLog(@"[%s] Failed to load OpenGL framework at path '%s'.",
                      funcName, path);
            }
        });
        return handle;
    }
    
    static bool IsOpenGLFrameworkAvailable() noexcept {
        return GetOpenGLFrameworkHandle() != nullptr;
    }
    
    static void *GetProcAddress(void *ctx, const char *sym) {
        return dlsym(ctx, sym);
    }
    
    static MPV::Result<CGLPixelFormatObj, CGLError>
    ChoosePixelFormat(const CGLPixelFormatAttribute *attrs) noexcept {
        GLint npix{};
        CGLPixelFormatObj result{};
        const auto err = CGLChoosePixelFormat(attrs, &result, &npix);
        return {result, err};
    }
    
    template<typename ...Ts> static MPV::Result<CGLPixelFormatObj, CGLError>
    ChoosePixelFormat(CGLPixelFormatAttribute arg, const Ts&...args) noexcept {
        const CGLPixelFormatAttribute attrs[] = {
            arg, args..., CGLPixelFormatAttribute(0) };
        return ChoosePixelFormat(attrs);
    }
    
    static MPV::Result<CGLPixelFormatObj, CGLError>
    ChoosePixelFormat() noexcept {
        MPV::Result<CGLPixelFormatObj, CGLError> res{};
        
        auto acceleratedPixelFormat = [&](CGLOpenGLProfile profile) {
            CGLPixelFormatAttribute attrs[] = {
                kCGLPFAOpenGLProfile, CGLPixelFormatAttribute(profile),
                kCGLPFAAccelerated,
                kCGLPFADoubleBuffer,
                kCGLPFABackingStore,
                kCGLPFAAllowOfflineRenderers,
                kCGLPFASupportsAutomaticGraphicsSwitching,
                CGLPixelFormatAttribute(0)
            };
            
            size_t nAttrs = sizeof(attrs) / sizeof(attrs[0]) - 1;
            while (nAttrs > 3) {
                if (res = ChoosePixelFormat(attrs); res.Value) {
                    return true;
                }
                attrs[--nAttrs] = CGLPixelFormatAttribute(0);
            }
            return false;
        };
        
        constexpr CGLOpenGLProfile profiles[] = { kCGLOGLPVersion_GL4_Core,
            kCGLOGLPVersion_GL3_Core, kCGLOGLPVersion_Legacy };
        for (const auto &profile : profiles) {
            if (acceleratedPixelFormat(profile)) {
                NSLog(@"[CGLRenderer] using '%x' OpenGL profile.", profile);
                return res;
            }
        }
        if (res = ChoosePixelFormat(kCGLPFARendererID,
            CGLPixelFormatAttribute(kCGLRendererGenericFloatID),
                                    kCGLPFADoubleBuffer); res.Value) {
            NSLog(@"[CGLRenderer] using software OpenGL.");
            return res;
        }
        if (res.Err == kCGLNoError) {
            // CGLChoosePixelFormat() can fail returning kCGLNoError
            res.Err = kCGLBadAttribute;
        }
        return res;
    }
    
    static MPV::Result<CGLContextObj, CGLError>
    CreateGLContext(CGLPixelFormatObj pix) noexcept {
        CGLContextObj cgl{};
        const auto e = CGLCreateContext(pix, /*shared context*/ nil, &cgl);
        return {cgl, e};
    }
    
    static MPV::Result<CGLContextObj, CGLError> CreateGLContext() noexcept {
        auto pix = MPV::CGLRenderer::ChoosePixelFormat();
        if (!pix.Value) {
            NSLog(@"[CGLRenderer] ChoosePixelFormat: %s", CGLErrorString(pix));
            return {nullptr, pix.Err};
        }
        auto cgl = CreateGLContext(pix);
        CGLReleasePixelFormat(pix);
        return cgl;
    }
    
    MPV::Result<void>
    init(mpv_handle *mpv, CGLContextObj cgl, bool advanced = false) noexcept {
        CGL = cgl;
        CGLSetCurrentContext(cgl);
        return Renderer::init(mpv, (mpv_render_param[]){
            { .type = MPV_RENDER_PARAM_API_TYPE,
              .data = const_cast<char*>(MPV_RENDER_API_TYPE_OPENGL)},
            { .type = MPV_RENDER_PARAM_OPENGL_INIT_PARAMS,
              .data = (mpv_opengl_init_params[]){
                    { .get_proc_address = &GetProcAddress,
                      .get_proc_address_ctx = GetOpenGLFrameworkHandle()}}},
            { .type = MPV_RENDER_PARAM_ADVANCED_CONTROL,
              .data = (int[]){advanced ? 1 : 0}},
            {}});
    }
    
    CGLContextObj CGL;
    mpv_opengl_fbo FBO;
    mpv_render_param Params[3];
    dispatch_queue_t Queue;
    
    CGLRenderer(const CGLRenderer&) = delete;
    CGLRenderer operator=(const CGLRenderer&) = delete;
    
    CGLRenderer() noexcept :
    Params{{.type = MPV_RENDER_PARAM_OPENGL_FBO, .data = &FBO}, {}, {}},
    Queue{dispatch_queue_create("com.mpv.cgl.render-queue",
                                DISPATCH_QUEUE_SERIAL)} {}
    
    void async(dispatch_block_t fn) const noexcept {
        dispatch_async(Queue, fn);
    }
        
    void async(void *ctx, dispatch_function_t fn) const noexcept {
        dispatch_async_f(Queue, ctx, fn);
    }
    
    void sync(dispatch_block_t fn) const noexcept {
        dispatch_sync(Queue, fn);
    }
        
    void deinit() noexcept {
        if (!isValid()) return;
        CGLClearDrawable(CGL);
        Renderer::deinit();
    }
    
    void setAuxParameter(const mpv_render_param &param) noexcept {
        Params[1] = param;
    }
    
    void setSize(int w, int h) noexcept {
        FBO.w = w;
        FBO.h = h;
    }
    
    auto &draw(const mpv_render_param *params) const noexcept {
        Renderer::draw(params);
        return *this;
    }
    
    auto &draw() const noexcept {
        return draw(Params);
    }
        
    auto &drawUntimed() const noexcept {
        return draw((mpv_render_param[]){ Params[0], Params[1],
            { .type = MPV_RENDER_PARAM_BLOCK_FOR_TARGET_TIME,
              .data = (int[]){0}}, {}});
    }
    
    auto &setCurrent() const noexcept {
        CGLSetCurrentContext(CGL);
        return *this;
    }
    
    auto &update() const noexcept {
        CGLUpdateContext(CGL);
        return *this;
    }
    
    void lock() const noexcept {
        CGLLockContext(CGL);
    }
    
    void unlock() const noexcept {
        CGLUnlockContext(CGL);
    }
    
    template<typename Fn>
    void lock(Fn expr) const noexcept {
        lock();
        expr();
        unlock();
    }
    
    auto &flush() const noexcept {
        CGLFlushDrawable(CGL);
        return *this;
    }
}; // struct CGLRenderer
} // namespace MPV

#endif /* CGLRenderer_h */
