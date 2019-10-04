//
//  MPVEventView.m
//  libmpvExamples
//
//  Created by Terminator on 2019/10/02.
//  Copyright © 2019年 home. All rights reserved.
//

#import "MPVEventView.h"
#import "MPVPlayer.h"

@implementation MPVEventView

- (instancetype)initWithPlayer:(MPVPlayer *)player {
    self = [super init];
    if (self) {

        _player = player;

    }
    return self;
}

#pragma mark - Overrides

- (BOOL)acceptsFirstResponder {
    return YES;
}

- (BOOL)acceptsFirstMouse:(NSEvent *)theEvent  {
    return YES;
}

- (BOOL)becomeFirstResponder {
    return YES;
}

- (BOOL)resignFirstResponder {
    return YES;
}

- (BOOL)wantsDefaultClipping {
    return NO;
}

- (BOOL)mouseDownCanMoveWindow {
    return YES;
}

- (void)keyDown:(NSEvent *)theEvent {
    NSString *chars = theEvent.charactersIgnoringModifiers;
    [_player performCommand:@"keydown" withArgument:chars];
}

- (void)keyUp:(NSEvent *)theEvent {
    NSString *chars = theEvent.characters;
    [_player performCommand:@"keyup" withArgument:chars];
}

@end
