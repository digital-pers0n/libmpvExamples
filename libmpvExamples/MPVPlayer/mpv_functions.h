//
//  mpv_functions.h
//  libmpvExamples
//
//  Created by Terminator on 2019/10/10.
//  Copyright © 2019年 home. All rights reserved.
//

#ifndef mpv_functions_h
#define mpv_functions_h

#include <mpv/client.h>

#define func_attributes inline __attribute__((overloadable, always_inline))

#pragma mark - mpv functions

static inline void mpv_print_log_message(struct mpv_event_log_message *msg) {
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

static int func_attributes mpv_perform_command_with_arguments(mpv_handle *mpv, const char *command, const char *arg1, const char *arg2, const char *arg3) {
    const char *cmd[] = { command, arg1, arg2, arg3, NULL };
    return mpv_command(mpv, cmd);
}

static int func_attributes mpv_perform_command_with_arguments(mpv_handle *mpv, const char *command, const char *arg1, const char *arg2) {
    const char *cmd[] = { command, arg1, arg2, NULL };
    return mpv_command(mpv, cmd);
}

static int func_attributes mpv_perform_command_with_argument(mpv_handle *mpv, const char *command, const char *arg1) {
    const char *cmd[] = { command, arg1, NULL };
    return mpv_command(mpv, cmd);
}

static int func_attributes mpv_perform_command(mpv_handle *mpv, const char *command) {
    const char *cmd[] = { command, NULL };
    return mpv_command(mpv, cmd);
}

#endif /* mpv_functions_h */
