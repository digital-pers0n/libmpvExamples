//
//  MPVTestGLView.h
//  libmpvExamples
//
//  Created by Terminator on 2019/12/21.
//  Copyright © 2019年 home. All rights reserved.
//

#import <Cocoa/Cocoa.h>

NS_ASSUME_NONNULL_BEGIN

@class MPVPlayer;

@interface MPVTestGLView : NSOpenGLView

@property (nonatomic) MPVPlayer *player;
- (void)destroyMPVRenderContext;

@end

NS_ASSUME_NONNULL_END
