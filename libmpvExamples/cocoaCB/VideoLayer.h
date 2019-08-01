//
//  VideoLayer.h
//  libmpvExamples
//
//  Created by Terminator on 2019/08/01.
//  Copyright © 2019年 home. All rights reserved.
//

#import <QuartzCore/QuartzCore.h>

typedef enum : NSUInteger {
    VideoLayerDrawNormal = 1,
    VideoLayerDrawAtomic,
    VideoLayerDrawAtomicEnd,
} VideoLayerDraw;

@class MPVHelper, CocoaCB;

@interface VideoLayer : CAOpenGLLayer

- (instancetype)initWithCocoaCB:(CocoaCB *)ccb;
- (void)update;
- (void)setVideo:(BOOL)state;

@end
