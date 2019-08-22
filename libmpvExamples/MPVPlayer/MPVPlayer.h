//
//  MPVPlayer.h
//  libmpvExamples
//
//  Created by Terminator on 2019/08/07.
//  Copyright © 2019年 home. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <mpv/client.h>

typedef NS_ENUM(NSInteger, MPVPlayerStatus) {
    MPVPlayerStatusUnknown,
    MPVPlayerStatusReadyToPlay,
    MPVPlayerStatusFailed
};

NS_ASSUME_NONNULL_BEGIN

@interface MPVPlayer : NSObject

@property (nonatomic, readonly, nullable) mpv_handle *mpv_handle;
@property (readonly, nullable) NSError *error;
@property (nonatomic, readonly) MPVPlayerStatus status;

- (void)openURL:(NSURL *)url;
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
- (NSString *)stringForProperty:(NSString *)property;
- (NSInteger)integerForProperty:(NSString *)property;
- (double)doubleForProperty:(NSString *)property;

#pragma mark - Commands

- (void)performCommand:(NSString *)command withArgument:(nullable NSString *)arg1 withArgument:(nullable NSString *)arg2;
- (void)performCommand:(NSString *)command withArgument:(nullable NSString *)arg1;
- (void)performCommand:(NSString *)command;

@end

NS_ASSUME_NONNULL_END
