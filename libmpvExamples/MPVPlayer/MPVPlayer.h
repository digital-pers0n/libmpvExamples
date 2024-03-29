//
//  MPVPlayer.h
//  libmpvExamples
//
//  Created by Terminator on 2019/08/07.
//  Copyright © 2019年 home. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <mpv/client.h>
#import "MPVPlayerProtocol.h"

typedef NS_ENUM(NSInteger, MPVPlayerStatus) {
    MPVPlayerStatusUnknown,
    MPVPlayerStatusReadyToPlay,
    MPVPlayerStatusFailed
};

NS_ASSUME_NONNULL_BEGIN

@protocol MPVPropertyObserving;

@interface MPVPlayer : NSObject<MPVPlayer>

@property (nonatomic, readonly, nullable) mpv_handle *mpv_handle;
@property (readonly, nullable) NSError *error;
@property (nonatomic, readonly) MPVPlayerStatus status;

- (void)loadURL:(NSURL *)url;
@property (nonatomic, nullable) NSURL *url;

#pragma mark - Playback Control

- (void)play;
- (void)pause;
- (void)stop;

@property (nonatomic) double speed;
@property (nonatomic) double timePosition;
@property (nonatomic) double percentPosition;
@property (nonatomic) double volume;
@property (nonatomic, getter=isMuted) BOOL muted;

- (void)shutdown;

#pragma mark - Properties

- (void)setBool:(BOOL)value forProperty:(NSString *)property;
- (void)setString:(NSString *)value forProperty:(NSString *)property;
- (void)setInteger:(NSInteger)value forProperty:(NSString *)property;
- (void)setDouble:(double)value forProperty:(NSString *)property;

- (BOOL)boolForProperty:(NSString *)property;
- (nullable NSString *)stringForProperty:(NSString *)property;
- (NSInteger)integerForProperty:(NSString *)property;
- (double)doubleForProperty:(NSString *)property;

#pragma mark - Commands

- (void)performCommand:(NSString *)command withArgument:(nullable NSString *)arg1 withArgument:(nullable NSString *)arg2;
- (void)performCommand:(NSString *)command withArgument:(nullable NSString *)arg1;
- (void)performCommand:(NSString *)command;

#pragma mark - Add/Remove Property Observers

- (void)addObserver:(id <MPVPropertyObserving>)observer forProperty:(NSString *)property format:(mpv_format)format;
- (void)removeObserver:(id <MPVPropertyObserving>)observer forProperty:(nullable NSString *)property;

@end

#pragma mark - Property Observing

@protocol MPVPropertyObserving <NSObject>

- (void)player:(MPVPlayer *)player didChangeValue:(id)value forProperty:(NSString *)property format:(mpv_format)format;

@end

#pragma mark - Notifications

/** MPV_EVENT_SHUTDOWN */
extern NSString * const MPVPlayerWillShutdownNotification;

/** MPV_EVENT_START_FILE */
extern NSString * const MPVPlayerWillStartPlaybackNotification;

/** MPV_EVENT_END_FILE */
extern NSString * const MPVPlayerDidEndPlaybackNotification;

/** MPV_EVENT_FILE_LOADED  */
extern NSString * const MPVPlayerDidLoadFileNotification;

/** MPV_EVENT_IDLE */
extern NSString * const MPVPlayerDidEnterIdleModeNotification;

/** MPV_EVENT_VIDEO_RECONFIG */
extern NSString * const MPVPlayerVideoDidChangeNotification;

/** MPV_EVENT_SEEK */
extern NSString * const MPVPlayerDidStartSeekNotification;

/** MPV_EVENT_PLAYBACK_RESTART */
extern NSString * const MPVPlayerDidRestartPlaybackNotification;

NS_ASSUME_NONNULL_END
