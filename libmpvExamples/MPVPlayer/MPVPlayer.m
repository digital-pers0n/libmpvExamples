//
//  MPVPlayer.m
//  libmpvExamples
//
//  Created by Terminator on 2019/08/07.
//  Copyright © 2019年 home. All rights reserved.
//

#import "MPVPlayer.h"

NSString * const MPVPlayerErrorDomain = @"com.home.mpvPlayer.ErrorDomain";
#define func_attributes __attribute__((overloadable, always_inline))

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
        if ([self setUp] != 0) {
            _status = MPVPlayerStatusFailed;
        } else {
            _status = MPVPlayerStatusReadyToPlay;
        }
    }
    return self;
}

- (int)setUp {
    _queue = dispatch_get_global_queue(QOS_CLASS_BACKGROUND, 0);
    
    mpv_handle *mpv = mpv_create();
    if (!mpv) {
        
        NSLog(@"Cannot create mpv_handle.");
        
        _error = [[NSError alloc]
                  initWithDomain:MPVPlayerErrorDomain
                            code:MPV_ERROR_GENERIC
                        userInfo:@{NSLocalizedDescriptionKey : @"Cannot create mpv_handle." }];
        
        return MPV_ERROR_GENERIC;
    }
    
    check_error( mpv_set_option_string(mpv, "hwdec", "videotoolbox"));
#ifdef ENABLE_LEGACY_GPU_SUPPORT
    check_error( mpv_set_option_string(mpv, "hwdec-image-format", "uyvy422"));
#endif
    check_error( mpv_request_log_messages(mpv, "warn"));
    
    int error = mpv_initialize(mpv);
    if (error < 0) {
        
        NSLog(@"Cannot initialize mpv_handle.");
        
        _error = [[NSError alloc]
                  initWithDomain:MPVPlayerErrorDomain
                            code:error
                        userInfo:@{ NSLocalizedDescriptionKey :
                                       [NSString stringWithFormat:@"%s\n", mpv_error_string(error)]
                                   }];
        mpv_destroy(mpv);
        return error;
    }
    
    check_error( mpv_set_option_string(mpv, "vo", "libmpv"));
    _mpv_handle = mpv;
    
    dispatch_async(_queue, ^{
        mpv_set_wakeup_callback(_mpv_handle, wakeup, (__bridge void *)self);
    });
    
    return 0;
}

- (void)dealloc
{
    if (_status == MPVPlayerStatusReadyToPlay) {
        [self shutdown];
    }
}

- (void)shutdown {
    mpv_destroy(_mpv_handle);
    _status = MPVPlayerStatusUnknown;
}

#pragma mark - Properties

- (void)setUrl:(NSURL *)url {
    _url = url;
    [self openURL:url];
}

#pragma mark - Methods

- (void)openURL:(NSURL *)url {
    const char *command[] = { "loadfile", url.fileSystemRepresentation, "append", NULL };
    mpv_command(_mpv_handle, command);
}

- (void)play {
    [self setBool:NO forProperty:@"pause"];
}

- (void)pause {
    [self setBool:YES forProperty:@"pause"];
}

- (void)setBool:(BOOL)value forProperty:(NSString *)property {
    mpv_set_value_for_key(_mpv_handle, (int)value, property.UTF8String);
}

- (void)setString:(NSString *)value forProperty:(NSString *)property {
    mpv_set_value_for_key(_mpv_handle, value.UTF8String, property.UTF8String);
}

- (void)setInteger:(NSInteger)value forProperty:(NSString *)property {
    mpv_set_value_for_key(_mpv_handle, (int64_t)value, property.UTF8String);
}

- (void)setDouble:(double)value forProperty:(NSString *)property {
    mpv_set_value_for_key(_mpv_handle, value, property.UTF8String);
}

- (BOOL)boolForProperty:(NSString *)property {
    int result = 0;
    mpv_get_value_for_key(_mpv_handle, &result, property.UTF8String);
    return result;
}

- (NSString *)stringForProperty:(NSString *)property {
    char *result = NULL;
    mpv_get_value_for_key(_mpv_handle, &result, property.UTF8String);
    if (result) {
        NSString *string = @(result);
        mpv_free(result);
        return string;
    }
    return nil;
}

- (NSInteger)integerForProperty:(NSString *)property {
    int64_t result = 0;
    mpv_get_value_for_key(_mpv_handle, &result, property.UTF8String);
    return result;
}

- (double)doubleForProperty:(NSString *)property {
    double result = 0;
    mpv_get_value_for_key(_mpv_handle, &result, property.UTF8String);
    return result;
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

#pragma mark - mpv functions

/**
 Set @c char string.
 */
static int func_attributes mpv_set_value_for_key(mpv_handle *mpv, const char *value, const char *key) {
    mpv_node node = {
        .u.string = (char *)value,
        .format = MPV_FORMAT_STRING
    };
    int error = mpv_set_property(mpv, key, MPV_FORMAT_NODE, &node);
    if (error < 0) {
        fprintf(stderr, "%s: Cannot set value '%s' for key '%s' -> (%d) %s\n", __PRETTY_FUNCTION__, value, key, error, mpv_error_string(error));
    }
    return error;
}

/**
 Set @c int flag.
 */
static int func_attributes mpv_set_value_for_key(mpv_handle *mpv, int value, const char *key) {
    mpv_node node = {
        .u.flag = value,
        .format = MPV_FORMAT_FLAG
    };
    int error = mpv_set_property(mpv, key, MPV_FORMAT_NODE, &node);
    if (error < 0) {
        fprintf(stderr, "%s: Cannot set value '%d' for key '%s' -> (%d) %s\n", __PRETTY_FUNCTION__, value, key, error, mpv_error_string(error));
    }
    return error;
}

/**
 Set @c int64_t value.
 */
static int func_attributes mpv_set_value_for_key(mpv_handle *mpv, int64_t value, const char *key) {
    mpv_node node = {
        .u.int64 = value,
        .format = MPV_FORMAT_INT64
    };
    int error = mpv_set_property(mpv, key, MPV_FORMAT_NODE, &node);
    if (error < 0) {
        fprintf(stderr, "%s: Cannot set value '%lld' for key '%s' -> (%d) %s\n", __PRETTY_FUNCTION__, value, key, error, mpv_error_string(error));
    }
    return error;
}

/**
 Set @c double value.
 */
static int func_attributes mpv_set_value_for_key(mpv_handle *mpv, double value, const char *key) {
    mpv_node node = {
        .u.double_ = value,
        .format = MPV_FORMAT_DOUBLE
    };
    int error = mpv_set_property(mpv, key, MPV_FORMAT_NODE, &node);
    if (error < 0) {
        fprintf(stderr, "%s: Cannot set value '%g' for key '%s' -> (%d) %s\n", __PRETTY_FUNCTION__, value, key, error, mpv_error_string(error));
    }
    return error;
}

/**
 Get @c char string. Free @c value with @c mpv_free() to avoid memory leaks.
 */
static int func_attributes mpv_get_value_for_key(mpv_handle *mpv, char **value, const char *key) {
    int error = mpv_get_property(mpv, key, MPV_FORMAT_STRING, value);
    if (error < 0) {
        fprintf(stderr, "%s: Cannot get value for key '%s' -> (%d) %s\n", __PRETTY_FUNCTION__, key, error, mpv_error_string(error));
    }
    return error;
}

/**
 Get @c int flag.
 */
static int func_attributes mpv_get_value_for_key(mpv_handle *mpv, int *value, const char *key) {
    int error = mpv_get_property(mpv, key, MPV_FORMAT_FLAG, value);
    if (error < 0) {
        fprintf(stderr, "%s: Cannot get value for key '%s' -> (%d) %s\n", __PRETTY_FUNCTION__, key, error, mpv_error_string(error));
    }
    return error;
}

/**
 Get @c int64_t value.
 */
static int func_attributes mpv_get_value_for_key(mpv_handle *mpv, int64_t *value, const char *key) {
    int error = mpv_get_property(mpv, key, MPV_FORMAT_INT64, value);
    if (error < 0) {
        fprintf(stderr, "%s: Cannot get value for key '%s' -> (%d) %s\n", __PRETTY_FUNCTION__, key, error, mpv_error_string(error));
    }
    return error;
}

/**
 Get @c double value.
 */
static int func_attributes mpv_get_value_for_key(mpv_handle *mpv, double *value, const char *key) {
    int error = mpv_get_property(mpv, key, MPV_FORMAT_DOUBLE, value);
    if (error < 0) {
        fprintf(stderr, "%s: Cannot get value for key '%s' -> (%d) %s\n", __PRETTY_FUNCTION__, key, error, mpv_error_string(error));
    }
    return error;
}

@end
