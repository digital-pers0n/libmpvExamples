//
//  MPVIOSurfaceView.h
//  libmpvExamples
//
//  Created by Terminator on 2020/04/02.
//  Copyright © 2020年 home. All rights reserved.
//

#import <Cocoa/Cocoa.h>

NS_ASSUME_NONNULL_BEGIN
@class MPVPlayer;

@interface MPVIOSurfaceView : NSView

@property (nonatomic) MPVPlayer *player;
- (void)destroyMPVRenderContext;

@end

NS_ASSUME_NONNULL_END
