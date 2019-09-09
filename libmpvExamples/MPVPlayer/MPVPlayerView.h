//
//  MPVPlayerView.h
//  libmpvExamples
//
//  Created by Terminator on 2019/08/13.
//  Copyright © 2019年 home. All rights reserved.
//

#import <Cocoa/Cocoa.h>

NS_ASSUME_NONNULL_BEGIN

@class MPVPlayer;

@interface MPVPlayerView : NSView

@property (readonly) MPVPlayer *player;
@property (nonatomic, readonly, getter=isReadyForDisplay) BOOL readyForDisplay;

@end

NS_ASSUME_NONNULL_END