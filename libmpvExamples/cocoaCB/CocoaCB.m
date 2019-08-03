//
//  CocoaCB.m
//  libmpvExamples
//
//  Created by Terminator on 2019/08/01.
//  Copyright © 2019年 home. All rights reserved.
//

#import "CocoaCB.h"
#import "Window.h"
#import "MPVHelper.h"
#import "VideoLayer.h"
#import "EventsView.h"
#import <mpv/client.h>

//#define ENABLE_LEGACY_GPU_SUPPORT 1

static inline void check_error(int status) {
    if (status < 0) {
        printf("mpv API error: %s\n", mpv_error_string(status));
    }
}

@implementation CocoaCB

- (instancetype)init
{
    self = [super init];
    if (self) {
        _title = @"CocoaCB";
        _queue = dispatch_get_global_queue(QOS_CLASS_BACKGROUND, 0);
        mpv_handle *mpv = mpv_create();
        check_error( mpv_set_option_string(mpv, "hwdec", "videotoolbox"));
#ifdef ENABLE_LEGACY_GPU_SUPPORT
        check_error( mpv_set_option_string(mpv, "hwdec-image-format", "uyvy422"));
#endif
        check_error( mpv_request_log_messages(mpv, "warn"));
        
        check_error( mpv_initialize(mpv));
        check_error( mpv_set_option_string(mpv, "vo", "libmpv"));
        _mpv = [MPVHelper.alloc initWithMpvHandle:mpv];
        
        _layer = [VideoLayer.alloc initWithCocoaCB:self];
        _view = [EventsView.alloc initWithCocoaCB:self];
        _view.layer = _layer;
        _view.wantsLayer = YES;
        _view.layerContentsPlacement = NSViewLayerContentsPlacementScaleProportionallyToFit;
        _window = [Window.alloc initWithContentRect:NSMakeRect(0, 0, 1280, 720) screen:[NSScreen mainScreen] view:_view cocoaCB:self];
        _window.title = _title;
        _window.restorable = NO;
        _window.movableByWindowBackground = YES;
        [NSApp activateIgnoringOtherApps:YES];
        [_window makeKeyAndOrderFront:nil];
        [_window center];
        _backendState = MPVStateInitialized;
        [_layer setVideo:YES];
        
        dispatch_async(_queue, ^{
            mpv_set_wakeup_callback(_mpv.mpv_handle, wakeup, (__bridge void *)self);
        });
        
    }
    return self;
}

- (void)dealloc {
    [self shutdown];
}

- (void)shutdown {
    if (_backendState == MPVStateInitialized) {
        [_layer setVideo:NO];
        [_window orderOut:nil];
        [_mpv deinitRender];
        [_mpv deinitMPV:YES];
    }
    _backendState = MPVStateUninitialized;
}

#pragma mark - mpv update callback

static inline void _print_mpv_message(struct mpv_event_log_message *msg) {
    printf("[%s]  %s : %s", msg->prefix, msg->level, msg->text);
}

static inline void _handle_event(CocoaCB *obj, mpv_event *event) {
    switch (event->event_id) {
            
        case MPV_EVENT_SHUTDOWN:
            [obj shutdown];
            break;
            
        case MPV_EVENT_LOG_MESSAGE:
            _print_mpv_message(event->data);
            
        default:
            printf("event: %s\n", mpv_event_name(event->event_id));
            break;
    }
}

static void read_events(void *ctx) {
    CocoaCB *obj = (__bridge id)ctx;
    while (obj->_mpv.mpv_handle) {
        mpv_event *event = mpv_wait_event(obj->_mpv.mpv_handle, 0);
        if (event->event_id == MPV_EVENT_NONE) {
            break;
        }
        _handle_event(obj, event);
    }
}

static void wakeup(void *ctx) {
    dispatch_async_f(dispatch_get_main_queue(), ctx, read_events);
}

@end
