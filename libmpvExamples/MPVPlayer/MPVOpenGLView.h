//
//  MPVOpenGLView.h
//  libmpvExamples
//
//  Created by Terminator on 2019/08/27.
//  Copyright © 2019年 home. All rights reserved.
//

#import <Cocoa/Cocoa.h>

NS_ASSUME_NONNULL_BEGIN

@class MPVPlayer;

@interface MPVOpenGLView : NSOpenGLView

@property (nonatomic, readonly) MPVPlayer *player;

@end

NS_ASSUME_NONNULL_END
