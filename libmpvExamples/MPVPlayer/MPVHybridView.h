//
//  MPVHybridView.h
//  libmpvExamples
//
//  Created by Terminator on 2019/09/14.
//  Copyright © 2019年 home. All rights reserved.
//

#import <Cocoa/Cocoa.h>

NS_ASSUME_NONNULL_BEGIN

@class MPVPlayer;

@interface MPVHybridView : NSOpenGLView

@property (nonatomic, readonly) MPVPlayer *player;

@end

NS_ASSUME_NONNULL_END
