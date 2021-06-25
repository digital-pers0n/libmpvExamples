//
//  CocoaCBExample.mm
//  libmpvExamples
//
//  Created by Terminator on 2021/6/21.
//  Copyright © 2021年 home. All rights reserved.
//

#import "CocoaCB.h"
#import "CocoaCBExample.h"

@implementation CocoaCBExample {
    CocoaCB *_ccb;
}

- (instancetype)initWithExampleName:(NSString *)str {
    if (!(self = [super init])) return nil;
    _ccb = [[CocoaCB alloc] init];
    return self;
}

- (void)shutdown {
    _ccb = nil;
}

- (id<MPVPlayer>)player {
    return (id<MPVPlayer>)_ccb.mpv;
}

- (NSWindow*)window {
    return (NSWindow*)_ccb.window;
}

@end
