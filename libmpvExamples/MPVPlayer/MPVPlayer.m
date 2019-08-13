//
//  MPVPlayer.m
//  libmpvExamples
//
//  Created by Terminator on 2019/08/07.
//  Copyright © 2019年 home. All rights reserved.
//

#import "MPVPlayer.h"

static inline void check_error(int status) {
    if (status < 0) {
        printf("mpv API error: %s\n", mpv_error_string(status));
        
    }
}

@interface MPVPlayer ()

@property (nonatomic) dispatch_queue_t queue;

@end

@implementation MPVPlayer

- (instancetype)init
{
    self = [super init];
    if (self) {
        _queue = dispatch_get_global_queue(QOS_CLASS_BACKGROUND, 0);
        mpv_handle *mpv = mpv_create();
        check_error( mpv_set_option_string(mpv, "hwdec", "videotoolbox"));
#ifdef ENABLE_LEGACY_GPU_SUPPORT
        check_error( mpv_set_option_string(mpv, "hwdec-image-format", "uyvy422"));
#endif
        check_error( mpv_request_log_messages(mpv, "warn"));
        
        check_error( mpv_initialize(mpv));
        check_error( mpv_set_option_string(mpv, "vo", "libmpv"));
        _mpv_handle = mpv;
        
        dispatch_async(_queue, ^{
            mpv_set_wakeup_callback(_mpv_handle, wakeup, (__bridge void *)self);
        });

    }
    return self;
}


#pragma mark - mpv update callback

static inline void _print_mpv_message(struct mpv_event_log_message *msg) {
    printf("[%s]  %s : %s", msg->prefix, msg->level, msg->text);
}

static inline void _handle_event(MPVPlayer *obj, mpv_event *event) {
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
    MPVPlayer *obj = (__bridge id)ctx;
    while (obj->_mpv_handle) {
        mpv_event *event = mpv_wait_event(obj->_mpv_handle, 0);
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
