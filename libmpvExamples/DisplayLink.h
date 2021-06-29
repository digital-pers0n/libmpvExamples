//
//  DisplayLink.h
//  libmpvExamples
//
//  Created by Terminator on 2021/6/28.
//  Copyright © 2021年 home. All rights reserved.
//

#ifndef DisplayLink_h
#define DisplayLink_h

#import <CoreVideo/CVDisplayLink.h>

struct DisplayLink {
    CVDisplayLinkRef CVDL;
    DisplayLink operator=(const DisplayLink&) = delete;
    DisplayLink(const DisplayLink&) = delete;
    
    DisplayLink() noexcept : CVDL{[]{
        CVDisplayLinkRef result{};
        CVDisplayLinkCreateWithActiveCGDisplays(&result);
        return result;
    }()} {}
    
    ~DisplayLink() noexcept {
        CVDisplayLinkRelease(CVDL);
        CVDL = nullptr;
    }
    
    bool isValid() const noexcept {
        return CVDL != nullptr;
    }
    
    CVReturn
    setCurrentDisplay(CGLContextObj ctx, CGLPixelFormatObj pf) const noexcept {
        return CVDisplayLinkSetCurrentCGDisplayFromOpenGLContext(CVDL, ctx, pf);
    }
    
    bool isRunning() const noexcept {
        return CVDisplayLinkIsRunning(CVDL);
    }
    
    void onUpdate(void *ctx, CVDisplayLinkOutputCallback fn) const noexcept {
        CVDisplayLinkSetOutputCallback(CVDL, fn, ctx);
    }
    
    void onUpdate(CVDisplayLinkOutputHandler fn) const noexcept {
        CVDisplayLinkSetOutputHandler(CVDL, fn);
    }
    
    void start() const noexcept {
        CVDisplayLinkStart(CVDL);
    }
    
    void stop() const noexcept {
        CVDisplayLinkStop(CVDL);
    }
}; // struct DisplayLink

#endif /* DisplayLink_h */
