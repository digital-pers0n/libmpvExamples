//
//  CocoaCB.h
//  libmpvExamples
//
//  Created by Terminator on 2019/08/01.
//  Copyright © 2019年 home. All rights reserved.
//

#import <Foundation/Foundation.h>

@class MPVHelper, Window, EventsView, VideoLayer;

typedef enum : NSUInteger {
    MPVStateUninitialized,
    MPVStateNeedsInit,
    MPVStateInitialized,
} MPVState;

@interface CocoaCB : NSObject

@property (nonatomic) MPVState backendState;
@property (nonatomic) MPVHelper *mpv;
@property (nonatomic) Window *window;
@property (nonatomic) EventsView *view;
@property (nonatomic) VideoLayer *layer;
@property (nonatomic) NSString *title;
@property (nonatomic) dispatch_queue_t queue;

@end
