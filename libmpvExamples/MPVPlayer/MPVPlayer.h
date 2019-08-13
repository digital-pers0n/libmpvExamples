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

- (void)openURL:(NSURL *)url;
@property (nonatomic, nullable) NSURL *url;
- (void)play;
- (void)pause;

- (void)shutdown;

@end

NS_ASSUME_NONNULL_END
