//
//  CocoaCBExample.h
//  libmpvExamples
//
//  Created by Terminator on 2021/6/21.
//  Copyright © 2021年 home. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import "MPVExampleProtocol.h"

NS_ASSUME_NONNULL_BEGIN

@protocol MPVPlayer;
@interface CocoaCBExample : NSObject<MPVExample>

@property (nonatomic, readonly) id<MPVPlayer> player;
@property (nonatomic, readonly) NSWindow *window;

@end

NS_ASSUME_NONNULL_END
