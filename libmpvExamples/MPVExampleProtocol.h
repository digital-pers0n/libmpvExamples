//
//  MPVExampleProtocol.h
//  libmpvExamples
//
//  Created by Terminator on 2020/05/09.
//  Copyright © 2020年 home. All rights reserved.
//

#import <Foundation/Foundation.h>

@protocol MPVPlayer;

@protocol MPVExample <NSObject>
- (instancetype)initWithExampleName:(NSString *)str;

@property (nonatomic, readonly) id<MPVPlayer> player;
@property (nonatomic, readonly) NSWindow *window;
- (void)shutdown;

@end
