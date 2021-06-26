//
//  Renderer.h
//  libmpvExamples
//
//  Created by Terminator on 2021/6/26.
//  Copyright © 2021年 home. All rights reserved.
//

#ifndef Renderer_h
#define Renderer_h

#import "Client.h"

#import <mpv/render.h>

namespace MPV {
struct Renderer {
    mpv_render_context *Ctx;
    
    MPV::Result<void>
    init(mpv_handle *mpv, const mpv_render_param *params) noexcept {
        const auto e = mpv_render_context_create(&Ctx, mpv,
                                        const_cast<mpv_render_param*>(params));
        return {e};
    }
    
    void deinit() noexcept {
        mpv_render_context_free(Ctx);
        Ctx = nullptr;
    }
    
    bool isValid() const noexcept {
        return Ctx != nullptr;
    }
    
    void onUpdate(void *ctx, mpv_render_update_fn cb) const noexcept {
        mpv_render_context_set_update_callback(Ctx, cb, ctx);
    }
    
    bool needsDisplay() const noexcept {
        return (mpv_render_context_update(Ctx) & MPV_RENDER_UPDATE_FRAME) > 0;
    }
    
    void draw(const mpv_render_param *params) const noexcept {
        mpv_render_context_render(Ctx, const_cast<mpv_render_param*>(params));
    }
}; // struct Renderer
} // namespace MPV

#endif /* Renderer_h */
