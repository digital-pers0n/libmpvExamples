//
//  MPVExample.h
//  libmpvExamples
//
//  Created by Terminator on 2020/05/09.
//  Copyright © 2020年 home. All rights reserved.
//

@import Cocoa;

NS_ASSUME_NONNULL_BEGIN

@protocol MPVPlayer;

@interface MPVExample : NSObject
- (instancetype)init NS_UNAVAILABLE;
- (instancetype)initWithExampleName:(NSString *)name;

@property (nonatomic, weak, nullable, readonly) id<MPVPlayer> player;
@property (nonatomic, nullable, readonly) NSWindow * window;
- (void)shutdown;

@end

NS_ASSUME_NONNULL_END
