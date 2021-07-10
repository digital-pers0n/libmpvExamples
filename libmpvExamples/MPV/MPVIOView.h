//
//  MPVIOView.h
//  libmpvExamples
//
//  Created by Terminator on 2021/7/4.
//  Copyright © 2021年 home. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import "MPVVideoRenderer.h"

NS_ASSUME_NONNULL_BEGIN

@interface MPVIOView : NSView<MPVVideoRenderer>
- (instancetype)initWithFrame:(NSRect)rect
                       client:(nullable MPVClient *)mpv NS_DESIGNATED_INITIALIZER;
@property (readonly, nonatomic) MPVClient *client;
@property (readonly, atomic, getter=isReadyForDisplay) BOOL readyForDisplay;
- (void)destroy;

@end

NS_ASSUME_NONNULL_END
