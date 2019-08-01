//
//  EventsView.h
//  libmpvExamples
//
//  Created by Terminator on 2019/08/01.
//  Copyright © 2019年 home. All rights reserved.
//

#import <Cocoa/Cocoa.h>
@class MPVHelper, CocoaCB;

@interface EventsView : NSView

- (instancetype)initWithCocoaCB:(CocoaCB *)ccb;
@property (weak, nonatomic) CocoaCB *cocoaCB;
@property (nonatomic) MPVHelper *mpv;
@property (nonatomic) NSTrackingArea *tracker;
@property (nonatomic) BOOL hasMouseDown;

@end
