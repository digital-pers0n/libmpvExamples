//
//  Window.h
//  libmpvExamples
//
//  Created by Terminator on 2019/08/01.
//  Copyright © 2019年 home. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@class MPVHelper, CocoaCB;

@interface Window : NSWindow <NSWindowDelegate>

- (instancetype)initWithContentRect:(NSRect)rect screen:(NSScreen *)screen view:(NSView *)view cocoaCB:(CocoaCB *)ccb;

@property (weak, nonatomic) CocoaCB *cocoaCB;
@property (nonatomic) MPVHelper *mpv;

- (void)showTitleBar;
- (void)hideTitleBar;
- (void)hideTitleBarDelayed;

@end
