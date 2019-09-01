//
//  MPVPlayerExample.h
//  libmpvExamples
//
//  Created by Terminator on 2019/08/29.
//  Copyright © 2019年 home. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@class MPVPlayer, MPVPlayerWindow;

@interface MPVPlayerExample : NSObject

@property (readonly, nonatomic) MPVPlayer *player;
@property (readonly, nonatomic) MPVPlayerWindow *window;

- (void)shutdown;

@end

NS_ASSUME_NONNULL_END