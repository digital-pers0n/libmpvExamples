//
//  MPVIOView.mm
//  libmpvExamples
//
//  Created by Terminator on 2021/7/4.
//  Copyright © 2021年 home. All rights reserved.
//

#import "MPVIOView.h"
#import "CGLRenderer.h"
#import "DisplayLink.h"
#import "MPVClient.h"

#import <QuartzCore/CATransaction.h>
#import <OpenGL/glext.h>

// Private CALayer API.
@interface CALayer (Private)
- (void)setContentsChanged;
- (void)reloadValueForKeyPath:(NSString *)keyPath;
@end

namespace {
struct IORenderer : public MPV::CGLRenderer {
    CALayer *Layer;
    GLuint Texture;
    CFMutableDictionaryRef Properties;
    
    IORenderer(const IORenderer&) = delete;
    IORenderer operator=(const IORenderer&) = delete;
    
    IORenderer() noexcept : Properties{[]{
        auto dict = CFDictionaryCreateMutable(kCFAllocatorDefault, /*size*/4,
                                             &kCFTypeDictionaryKeyCallBacks,
                                             &kCFTypeDictionaryValueCallBacks);
        auto num = CFNumberCreate(kCFAllocatorDefault, kCFNumberIntType,
                                  (int[]){4});
        CFDictionarySetValue(dict, kIOSurfaceBytesPerElement,
                             CFAutorelease(num));
        num = CFNumberCreate(kCFAllocatorDefault, kCFNumberIntType,
                             (int[]){kCVPixelFormatType_32BGRA});
        CFDictionarySetValue(dict, kIOSurfacePixelFormat, CFAutorelease(num));
        return dict;
    }()} {}
    
    ~IORenderer() noexcept {
        CFRelease(Properties);
    }
    
    void deinit() noexcept {
        CGLRenderer::deinit();
        if (CGL) {
            CGLDestroyContext(CGL);
            CGL = nil;
        }
    }
    
    IOSurfaceRef createSurface(int w, int h) const noexcept {
        auto num = CFNumberCreate(kCFAllocatorDefault, kCFNumberIntType, &w);
        CFDictionarySetValue(Properties, kIOSurfaceWidth, num);
        CFRelease(num);
        num = CFNumberCreate(kCFAllocatorDefault, kCFNumberIntType, &h);
        CFDictionarySetValue(Properties, kIOSurfaceHeight, num);
        CFRelease(num);
        return IOSurfaceCreate(Properties);
    }
    
    template<typename Fn> auto &surface(Fn expr) const noexcept {
        auto io = createSurface(FBO.w, FBO.h);
        expr(io);
        CFRelease(io);
        return *this;
    }
    
    auto &bindTexture(IOSurfaceRef io) noexcept {
        if (Texture) {
            glDeleteTextures(1, &Texture);
        }
        
        GLuint tex{};
        glGenTextures(1, &tex);
        glBindTexture(GL_TEXTURE_RECTANGLE_ARB, tex);
        auto e = CGLTexImageIOSurface2D(CGL, GL_TEXTURE_RECTANGLE_ARB,
                 /*internal_format*/ GL_RGBA,
                 GLsizei(FBO.w), GLsizei(FBO.h), /*format*/ GL_BGRA,
                 /*type*/GL_UNSIGNED_INT_8_8_8_8_REV, io, /*plane*/ 0);
        if (e != kCGLNoError) {
            NSLog(@"%s: %d '%s'", __PRETTY_FUNCTION__, e, CGLErrorString(e));
        }
        glBindTexture(GL_TEXTURE_RECTANGLE_ARB, 0);
        Texture = tex;
        return *this;
    }
        
    auto &bindFramebuffer() noexcept {
        if (FBO.fbo) {
            glDeleteFramebuffers(1, reinterpret_cast<GLuint*>(&FBO.fbo));
        }
        
        GLuint fbo{};
        glGenFramebuffers(1, &fbo);
        glBindFramebuffer(GL_FRAMEBUFFER, fbo);
        glBindTexture(GL_TEXTURE_RECTANGLE_ARB, Texture);
        glFramebufferTexture2D(GL_FRAMEBUFFER, GL_COLOR_ATTACHMENT0,
                               GL_TEXTURE_RECTANGLE_ARB, Texture, /*level*/ 0);
#if DEBUG
        auto e = glCheckFramebufferStatus(GL_FRAMEBUFFER);
        if (e != GL_FRAMEBUFFER_COMPLETE) {
            NSLog(@"%s: Incomplete framebuffer: %u", __PRETTY_FUNCTION__, e);
        }
#endif
        glBindFramebuffer(GL_FRAMEBUFFER, 0);
        glBindTexture(GL_TEXTURE_RECTANGLE_ARB, 0);
        FBO.fbo = fbo;
        return *this;
    }
        
    void beginTransaction() const noexcept {
        [CATransaction begin];
    }
        
    void endTransaction() const noexcept {
        [CATransaction commit];
    }
    
    template<typename Fn> auto &transaction(Fn expr) const noexcept {
        beginTransaction();
        expr();
        endTransaction();
        return *this;
    }
        
    auto &disableActions() const noexcept {
        [CATransaction setValue:(id)kCFBooleanTrue
                         forKey:kCATransactionDisableActions];
        return *this;
    }
    
    auto &setCurrent() noexcept {
        CGLRenderer::setCurrent();
        return *this;
    }
    
    auto &setCurrent() const noexcept {
        CGLRenderer::setCurrent();
        return *this;
    }
    
    auto &flush() const noexcept {
        CGLRenderer::flush();
        return *this;
    }
    
    auto &draw() const noexcept {
        CGLRenderer::draw();
        return *this;
    }
    
    auto &update() const noexcept {
        CGLRenderer::update();
        return *this;
    }
    
    auto &updateLayer(IOSurfaceRef io, const NSRect &frame) const noexcept {
        Layer.bounds = frame;
        Layer.contents = (__bridge id)io;
        return *this;
    }
    
    auto &reloadContents() const noexcept {
        [Layer reloadValueForKeyPath:@"contents"];
        return *this;
    }
    
    auto &updateSurface(const NSRect &frame, const NSSize &fboSize) noexcept {
        setSize(fboSize.width, fboSize.height);
        surface([&](IOSurfaceRef io){
            setCurrent().bindTexture(io).bindFramebuffer().transaction([&]{
                disableActions().updateLayer(io, frame).draw().flush();
            });
        });
        return *this;
    }
    
}; // struct IORenderer
} // anonymous namespace

[[clang::objc_direct_members]]
@implementation MPVIOView {
    IORenderer _cgl;
    DisplayLink _displayLink;
}
//MARK:- MPVVideoRenderer

- (instancetype)initWithFrame:(NSRect)rect client:(MPVClient *)mpv {
    if (!MPV::CGLRenderer::IsOpenGLFrameworkAvailable()) return nil;
    if (!(self = [super initWithFrame:rect])) return nil;
    
    if (!mpv) {
        mpv = [MPVClient new];
    }
    
    if (!mpv.isReadyToPlay) {
        NSLog(@"[MPVIOView] Client: %@ cannot be used for video playback", mpv);
        return nil;
    }
    
    auto cgl = MPV::CGLRenderer::CreateGLContext();
    if (!cgl.Value) {
        NSLog(@"[MPVIOView] CreateGLContext: %s", CGLErrorString(cgl));
        return nil;
    }
    
    if (const auto res = _cgl.init(reinterpret_cast<mpv_handle*>(mpv.handle),
                                   cgl); !res) {
        NSLog(@"[MPVIOView] Cannot create IORenderer %s", res.Err.string());
        return nil;
    }
    
    CGLSetParameter(cgl, kCGLCPSwapInterval, (GLint[]){1});
    static int flag = 0;
    _cgl.setAuxParameter({ .type = MPV_RENDER_PARAM_BLOCK_FOR_TARGET_TIME,
                           .data = &flag });
    
    auto blackColor = CGColorGetConstantColor(kCGColorBlack);
    auto layer = [CALayer layer];
    layer.opaque = YES;
    layer.contentsGravity = kCAGravityResizeAspect;
    layer.backgroundColor = blackColor;
    layer.anchorPoint = {};
    layer.bounds = rect;
    layer.doubleSided = NO;
    self.wantsLayer = YES;
    self.layer.opaque = YES;
    self.layer.backgroundColor = blackColor;
    [self.layer addSublayer:layer];
    self.layerContentsRedrawPolicy = NSViewLayerContentsRedrawDuringViewResize;
    _cgl.Layer = layer;
    _readyForDisplay = YES;
    _client = mpv;
    [self setUpResizeMode];
    
    return self;
}

- (void)destroy {
    if (!_readyForDisplay) return;
    _readyForDisplay = NO;
    if (_displayLink.isRunning()) {
        [self exitResizeMode];
    } else {
        [self exitPlaybackMode];
    }
    _cgl.deinit();
}

//MARK:- Methods

- (void)enterPlaybackMode {
    _cgl.onUpdate(&_cgl, [](void *ctx){
        const auto &cgl = *reinterpret_cast<IORenderer*>(ctx);
        cgl.async(ctx, [](void *ctx){
            const auto &cgl = *reinterpret_cast<IORenderer*>(ctx);
            cgl.setCurrent().draw().flush().reloadContents().endTransaction();
        });
    });
    self.needsDisplay = YES;
}

- (void)exitPlaybackMode {
    _cgl.onUpdate({}, {});
    _cgl.sync(^{}); // make sure the render queue is empty
}

- (void)setUpResizeMode {
    _displayLink.onUpdate(&_cgl,
    [](CVDisplayLinkRef CV_NONNULL, const CVTimeStamp * CV_NONNULL,
       const CVTimeStamp * CV_NONNULL, CVOptionFlags,
       CVOptionFlags * CV_NONNULL, void * CV_NULLABLE ctx) -> CVReturn {
        
        const auto &cgl = *reinterpret_cast<IORenderer*>(ctx);
        cgl.lock([&]{
            if (!cgl.needsDisplay()) return;
            cgl.setCurrent().update().transaction([&]{
                cgl.draw().flush().reloadContents();
            });
        });
        return kCVReturnSuccess;
    });
}

- (void)enterResizeMode {
    _displayLink.start();
    self.needsDisplay = YES;
}

- (void)exitResizeMode {
    _displayLink.stop();
}

//MARK:- Overrides

- (instancetype)initWithFrame:(NSRect)rect {
    return [self initWithFrame:rect client:nil];
}

- (instancetype)initWithCoder:(NSCoder *)coder {
    [NSException raise:NSInvalidArgumentException format:@"Not implemented"];
    return [self initWithFrame:{} client:nil];
}

- (void)dealloc {
    [self destroy];
}

- (void)updateLayer {
    const auto ioFrame = self.bounds;
    const auto fboSize = [self convertSizeToBacking:ioFrame.size];
    auto updater = [&, &cgl = _cgl]{ cgl.updateSurface(ioFrame, fboSize); };
    
    if (_displayLink.isRunning()) {
        _cgl.lock(updater);
    } else {
        _cgl.sync(^{updater();});
    }
}

- (void)viewWillStartLiveResize {
    [super viewWillStartLiveResize];
    if (!_readyForDisplay) return;
    [self exitPlaybackMode];
    [self enterResizeMode];
}

- (void)viewDidEndLiveResize {
    [super viewDidEndLiveResize];
    if (!_readyForDisplay) return;
    [self exitResizeMode];
    [self enterPlaybackMode];
}

- (void)viewDidMoveToWindow {
    [super viewDidMoveToWindow];
    if (!_readyForDisplay) return;
    if (self.window) {
        [self enterPlaybackMode];
    } else {
        if (_displayLink.isRunning()) {
            [self exitResizeMode];
        } else {
            [self exitPlaybackMode];
        }
    }
}

- (BOOL)wantsUpdateLayer {
    return _readyForDisplay;
}

- (BOOL)isOpaque {
    return YES;
}

- (BOOL)mouseDownCanMoveWindow {
    return YES;
}

@end
