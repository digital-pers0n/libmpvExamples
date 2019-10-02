//
//  MPVPlayer.m
//  libmpvExamples
//
//  Created by Terminator on 2019/08/07.
//  Copyright © 2019年 home. All rights reserved.
//

#import "MPVPlayer.h"
#import "MPVPlayerProperties.h"
#import "MPVPlayerCommands.h"

NSString * const MPVPlayerErrorDomain = @"com.home.mpvPlayer.ErrorDomain";
#define func_attributes __attribute__((overloadable, always_inline))

#define mpv_print_error_set_property(error_code, property_name, value_format, value) \
        NSLog(@"%s Failed to set value '" value_format "' for property '%@' -> %d %s", \
                __PRETTY_FUNCTION__, value, property_name, error_code, mpv_error_string(error_code))

#define mpv_print_error_get_property(error_code, property_name) \
        NSLog(@"%s Failed to get value for property '%@' -> %d %s", \
                __PRETTY_FUNCTION__, property_name, error_code, mpv_error_string(error_code))

#define mpv_print_error_generic(error_code, format, ...) \
        NSLog(@"%s " format " -> %d %s", \
                __PRETTY_FUNCTION__, ##__VA_ARGS__, error_code, mpv_error_string(error_code))

static inline void check_error(int status) {
    if (status < 0) {
        printf("mpv API error: %s\n", mpv_error_string(status));
        
    }
}

@interface MPVPlayer ()

@property NSThread *eventThread;
@property NSNotificationCenter *notificationCenter;

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
    
    _notificationCenter = [NSNotificationCenter defaultCenter];
    
    _eventThread = [[NSThread alloc] initWithTarget:self selector:@selector(readEvents) object:nil];
    _eventThread.qualityOfService = QOS_CLASS_UTILITY;
    _eventThread.name = @"com.home.mpvPlayer.EventThread";
    [_eventThread start];
    
    return 0;
}

- (void)dealloc
{
    if (_status == MPVPlayerStatusReadyToPlay) {
        [self shutdown];
    }
}

- (void)readEvents {

    NSString *notification = nil;
    SEL postNotification = @selector(postNotification:);
    
    while (!_eventThread.cancelled) {
        mpv_event *event = mpv_wait_event(self->_mpv_handle, -1);
        switch (event->event_id) {
                
            case MPV_EVENT_NONE:
                goto exit;
                
            case MPV_EVENT_SHUTDOWN:
            {
                if (self->_status == MPVPlayerStatusReadyToPlay) {
                    [self performSelectorOnMainThread:@selector(shutdown) withObject:nil waitUntilDone:NO];
                }
            }
                goto exit;
                
            case MPV_EVENT_LOG_MESSAGE:
                mpv_print_message(event->data);
                break;
                
            case MPV_EVENT_START_FILE:
                notification = MPVPlayerWillStartPlaybackNotification;
                break;
                
            case MPV_EVENT_END_FILE:
                notification = MPVPlayerDidEndPlaybackNotification;
                break;
                
            case MPV_EVENT_FILE_LOADED:
                notification = MPVPlayerDidLoadFileNotification;
                break;
                
            case MPV_EVENT_IDLE:
                notification = MPVPlayerDidEnterIdleModeNotification;
                break;
                
            case MPV_EVENT_VIDEO_RECONFIG:
                notification = MPVPlayerVideoDidChangeNotification;
                break;
                
            case MPV_EVENT_SEEK:
                notification = MPVPlayerDidStartSeekNotification;
                break;
                
            case MPV_EVENT_PLAYBACK_RESTART:
                notification = MPVPlayerDidRestartPlaybackNotification;
                break;
                
            default:
                printf("event: %s\n", mpv_event_name(event->event_id));
                break;
        }
        
        if (notification) {
#ifdef DEBUG
            NSLog(@"Post '%@' notification.", notification);
#endif
            [self performSelectorOnMainThread:postNotification withObject:notification waitUntilDone:NO];
            
            notification = nil;
        }
        
    }
    
exit:
    [NSThread exit];
}

- (void)shutdown {
    [_eventThread cancel];
    _status = MPVPlayerStatusUnknown;
    
    [NSNotificationCenter.defaultCenter postNotificationName:MPVPlayerWillShutdownNotification object:self userInfo:nil];

    [self performCommand:@"quit"];
    mpv_terminate_destroy(_mpv_handle);
    _mpv_handle = NULL;
}

- (void)postNotification:(NSString *)notification {
    [_notificationCenter postNotificationName:notification object:self userInfo:nil];
}

#pragma mark - Properties

- (void)setUrl:(NSURL *)url {
    _url = url;
    [self openURL:url];
}

- (void)setSpeed:(double)speed {
    [self setDouble:speed forProperty:MPVPlayerPropertySpeed];
}

- (double)speed {
    return [self doubleForProperty:MPVPlayerPropertySpeed];
}

- (double)timePosition {
    return [self boolForProperty:MPVPlayerPropertyTimePosition];
}

- (void)setTimePosition:(double)currentTimePosition {
    [self setDouble:currentTimePosition forProperty:MPVPlayerPropertyTimePosition];
}

- (double)percentPosition {
    return [self doubleForProperty:MPVPlayerPropertyPercentPosition];
}

- (void)setPercentPosition:(double)percentPosition {
    [self setDouble:percentPosition forProperty:MPVPlayerPropertyPercentPosition];
}

- (double)volume {
    return [self doubleForProperty:MPVPlayerPropertyVolume];
}

- (void)setVolume:(double)volume {
    [self setDouble:volume forProperty:MPVPlayerPropertyVolume];
}

- (BOOL)isMuted {
    return [self boolForProperty:MPVPlayerPropertyMute];
}

- (void)setMuted:(BOOL)muted {
    [self setBool:muted forProperty:MPVPlayerPropertyMute];
}

#pragma mark - Methods

- (void)performCommand:(const char *)command arguments:(const char *)arg, ... NS_REQUIRES_NIL_TERMINATION {
    va_list args;
    va_start(args, arg);
}

- (void)openURL:(NSURL *)url {
    [self performCommand:MPVPlayerCommandLoadFile withArgument:url.absoluteString withArgument:nil];
}

- (void)play {
    [self setBool:NO forProperty:MPVPlayerPropertyPause];
}

- (void)pause {
    [self setBool:YES forProperty:MPVPlayerPropertyPause];
}

- (void)stop {
    [self performCommand:MPVPlayerCommandStop];
}

- (void)setBool:(BOOL)value forProperty:(NSString *)property {
    int error = mpv_set_value_for_key(_mpv_handle, (int)value, property.UTF8String);
    if (error != MPV_ERROR_SUCCESS) {
        mpv_print_error_set_property(error, property, "%d", value);
    }
}

- (void)setString:(NSString *)value forProperty:(NSString *)property {
    int error = mpv_set_value_for_key(_mpv_handle, value.UTF8String, property.UTF8String);
    if (error != MPV_ERROR_SUCCESS) {
        mpv_print_error_set_property(error, property, "%@", value);
    }
}

- (void)setInteger:(NSInteger)value forProperty:(NSString *)property {
    int error = mpv_set_value_for_key(_mpv_handle, (int64_t)value, property.UTF8String);
    if (error != MPV_ERROR_SUCCESS) {
        mpv_print_error_set_property(error, property, "%ld", value);
    }
}

- (void)setDouble:(double)value forProperty:(NSString *)property {
    int error = mpv_set_value_for_key(_mpv_handle, value, property.UTF8String);
    if (error != MPV_ERROR_SUCCESS) {
        mpv_print_error_set_property(error, property, "%g", value);
    }
}

- (BOOL)boolForProperty:(NSString *)property {
    int result = 0;
    int error = mpv_get_value_for_key(_mpv_handle, &result, property.UTF8String);
    if (error != MPV_ERROR_SUCCESS) {
        mpv_print_error_get_property(error, property);
    }
    return result;
}

- (NSString *)stringForProperty:(NSString *)property {
    char *result = NULL;
    int error = mpv_get_value_for_key(_mpv_handle, &result, property.UTF8String);
    if (result) {
        NSString *string = @(result);
        mpv_free(result);
        return string;
    } else {
        if (error != MPV_ERROR_SUCCESS) {
            mpv_print_error_get_property(error, property);
        }
    }
    
    return nil;
}

- (NSInteger)integerForProperty:(NSString *)property {
    int64_t result = 0;
    int error = mpv_get_value_for_key(_mpv_handle, &result, property.UTF8String);
    if (error != MPV_ERROR_SUCCESS) {
        mpv_print_error_get_property(error, property);
    }
    return result;
}

- (double)doubleForProperty:(NSString *)property {
    double result = 0;
    int error = mpv_get_value_for_key(_mpv_handle, &result, property.UTF8String);
    if (error != MPV_ERROR_SUCCESS) {
        mpv_print_error_get_property(error, property);
    }
    return result;
}

- (void)performCommand:(NSString *)command withArgument:(NSString *)arg1 withArgument:(NSString *)arg2 {
    int error = mpv_perform_command_with_arguments(_mpv_handle, command.UTF8String, arg1.UTF8String, arg2.UTF8String);
    if (error != MPV_ERROR_SUCCESS) {
        mpv_print_error_generic(error, "Failed to perform command '%@' with arguments '%@', '%@'", command, arg1, arg2);
    }
}

- (void)performCommand:(NSString *)command withArgument:(NSString *)arg1 {
    int error = mpv_perform_command_with_arguments(_mpv_handle, command.UTF8String, arg1.UTF8String, NULL);
    if (error != MPV_ERROR_SUCCESS) {
        mpv_print_error_generic(error, "Failed to perform command '%@' with argument '%@'", command, arg1);
    }
}

- (void)performCommand:(NSString *)command {
    int error = mpv_perform_command_with_arguments(_mpv_handle, command.UTF8String, NULL, NULL);
    if (error != MPV_ERROR_SUCCESS) {
        mpv_print_error_generic(error, "Failed to perform command '%@'", command);
    }
}

#pragma mark - mpv functions

static inline void mpv_print_message(struct mpv_event_log_message *msg) {
    printf("[%s]  %s : %s", msg->prefix, msg->level, msg->text);
}

#pragma mark set/get mpv properties

/**
 Set @c char string.
 */
static int func_attributes mpv_set_value_for_key(mpv_handle *mpv, const char *value, const char *key) {
    mpv_node node = {
        .u.string = (char *)value,
        .format = MPV_FORMAT_STRING
    };
    return mpv_set_property(mpv, key, MPV_FORMAT_NODE, &node);
}

/**
 Set @c int flag.
 */
static int func_attributes mpv_set_value_for_key(mpv_handle *mpv, int value, const char *key) {
    mpv_node node = {
        .u.flag = value,
        .format = MPV_FORMAT_FLAG
    };
    return mpv_set_property(mpv, key, MPV_FORMAT_NODE, &node);
}

/**
 Set @c int64_t value.
 */
static int func_attributes mpv_set_value_for_key(mpv_handle *mpv, int64_t value, const char *key) {
    mpv_node node = {
        .u.int64 = value,
        .format = MPV_FORMAT_INT64
    };
    return mpv_set_property(mpv, key, MPV_FORMAT_NODE, &node);
}

/**
 Set @c double value.
 */
static int func_attributes mpv_set_value_for_key(mpv_handle *mpv, double value, const char *key) {
    mpv_node node = {
        .u.double_ = value,
        .format = MPV_FORMAT_DOUBLE
    };
    return mpv_set_property(mpv, key, MPV_FORMAT_NODE, &node);
}

/**
 Get @c char string. Free @c value with @c mpv_free() to avoid memory leaks.
 */
static int func_attributes mpv_get_value_for_key(mpv_handle *mpv, char **value, const char *key) {
    return mpv_get_property(mpv, key, MPV_FORMAT_STRING, value);
}

/**
 Get @c int flag.
 */
static int func_attributes mpv_get_value_for_key(mpv_handle *mpv, int *value, const char *key) {
    return mpv_get_property(mpv, key, MPV_FORMAT_FLAG, value);
}

/**
 Get @c int64_t value.
 */
static int func_attributes mpv_get_value_for_key(mpv_handle *mpv, int64_t *value, const char *key) {
    return mpv_get_property(mpv, key, MPV_FORMAT_INT64, value);
}

/**
 Get @c double value.
 */
static int func_attributes mpv_get_value_for_key(mpv_handle *mpv, double *value, const char *key) {
    return mpv_get_property(mpv, key, MPV_FORMAT_DOUBLE, value);
}

#pragma mark mpv commands

static inline int mpv_perform_command_with_arguments(mpv_handle *mpv, const char *command, const char *arg1, const char *arg2) {
    const char *cmd[] = { command, arg1, arg2, NULL };
    return mpv_command(mpv, cmd);
}

@end
