//
//  MPVPlayerLayer.h
//  libmpvExamples
//
//  Created by Terminator on 2019/08/27.
//  Copyright © 2019年 home. All rights reserved.
//

#import <QuartzCore/QuartzCore.h>

NS_ASSUME_NONNULL_BEGIN

@class MPVPlayer;

@interface MPVPlayerLayer : CAOpenGLLayer

@property (readonly, nonatomic) MPVPlayer *player;

@end

NS_ASSUME_NONNULL_END