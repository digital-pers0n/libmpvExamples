# libmpv Examples

mpv client API examples for macOS

## List of examples

### CocoaCB

CAOpenGLLayer example. Based on CocoaCB from mpv 0.29.1

### MPVPlayer

#### MPVOpenGLView

NSOpenGLView subclass. Low CPU/GPU usage, choppy live resize.

#### MPVPlayerView

NSView subclass. Highly experimental and very glitchy.

#### MPVHybridView

NSOpenGLView + CAOpenGLLayer. Live resize is smooth, but it has glitches.

#### MPVPlayerLayer

CAOpenGLLayer subclass. Smoothest live resize, but in comparison with other examples has higher CPU/GPU usage.

#### MPVTestGLView

Same as the MPVOpenGLView example, but it doesn't use the `mpv_render_context_set_update_callback()` function, it utilizes the `CVDisplayLinkCallback`. Since you can use the `mpv_render_context_render()` directly inside the `CVDisplayLinkCallback` function you don't have to call the `dispatch_async()` or spawning separate threads. This approach slightly reduces CPU usage during video playback, it also makes live resize smoother.


