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

@property (nonatomic) CocoaCB *cocoaCB;
@property (nonatomic) MPVHelper *mpv;

@property (nonatomic) NSLock *videoLock;
@property (nonatomic) NSLock *displayLock;

@property (nonatomic) BOOL hasVideo;
@property (nonatomic) BOOL needsFlip;
@property (nonatomic) BOOL canDrawOffScreen;
@property (nonatomic) CGLContextObj cglContext;
@property (nonatomic) CGLPixelFormatObj cglPixelFormat;
@property (nonatomic) NSSize surfaceSize;
@property (nonatomic) VideoLayerDraw draw;
@property (nonatomic) dispatch_queue_t queue;
@property (nonatomic) BOOL inLiveResize;

@end
