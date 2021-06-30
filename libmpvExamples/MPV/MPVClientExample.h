//
//  MPVClientExample.h
//  libmpvExamples
//
//  Created by Terminator on 2021/6/22.
//  Copyright © 2021年 home. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import "MPVExampleProtocol.h"

NS_ASSUME_NONNULL_BEGIN

@protocol MPVPlayer;

@interface MPVClientExample : NSObject<MPVExample>

- (instancetype)initWithExampleName:(NSString *)str;
@property (nullable, nonatomic, readonly) id<MPVPlayer> player;
@property (nullable, nonatomic, readonly) NSWindow *window;
- (void)shutdown;

@end

NS_ASSUME_NONNULL_END
