//
//  MPVGLView.h
//  libmpvExamples
//
//  Created by Terminator on 2021/6/13.
//  Copyright © 2021年 home. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import "MPVVideoRenderer.h"

NS_ASSUME_NONNULL_BEGIN

@interface MPVGLView : NSOpenGLView<MPVVideoRenderer>
@property (readonly, nonatomic) MPVClient *client;
@property (readonly, atomic, getter=isReadyForDisplay) BOOL readyForDisplay;
@end

NS_ASSUME_NONNULL_END
