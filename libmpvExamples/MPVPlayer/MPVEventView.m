//
//  MPVEventView.m
//  libmpvExamples
//
//  Created by Terminator on 2019/10/02.
//  Copyright © 2019年 home. All rights reserved.
//

#import "MPVEventView.h"
#import "MPVPlayer.h"
#import "MPVPlayerProperties.h"

#define createMessageFrom(target, sel) [[MPVMessage alloc] initWithTarget:target action:@selector(sel)]

@interface MPVMessage : NSObject {
    @package
    __weak id _target;
    SEL _action;
    IMP _methodImplementation;
}

- (instancetype)initWithTarget:(id)target action:(SEL)selector;

@end

@implementation MPVMessage

- (instancetype)initWithTarget:(id)target action:(SEL)selector
{
    self = [super init];
    if (self) {
        _target = target;
        _action = selector;
        _methodImplementation = [target methodForSelector:selector];
    }
    return self;
}

@end

@interface MPVEventView () <MPVPropertyObserving>
@property NSDictionary *observed;
@end

@implementation MPVEventView

- (instancetype)initWithPlayer:(MPVPlayer *)player {
    self = [super init];
    if (self) {

        _observed = @{
                      MPVPlayerPropertyPause    : createMessageFrom(self, pauseDidChange:),
                      MPVPlayerPropertyMute     : createMessageFrom(self, muteDidChange:),
                      MPVPlayerPropertyVolume   : createMessageFrom(self, volumeDidChange:),
                      MPVPlayerPropertyFilename : createMessageFrom(self, filenameDidChange:)};
        
        _player = player;
        [_player addObserver:self
                 forProperty:MPVPlayerPropertyPause
                      format:MPV_FORMAT_FLAG];
        
        [_player addObserver:self
                 forProperty:MPVPlayerPropertyVolume
                      format:MPV_FORMAT_DOUBLE];
        
        [_player addObserver:self
                 forProperty:MPVPlayerPropertyMute
                      format:MPV_FORMAT_FLAG];
        
        [_player addObserver:self
                 forProperty:MPVPlayerPropertyFilename
                      format:MPV_FORMAT_STRING];

    }
    return self;
}

#pragma mark - MPV property observing

- (void)volumeDidChange:(NSNumber *)value {
    NSLog(@"\n%s - new volume value: %g", __PRETTY_FUNCTION__, value.doubleValue);
}

- (void)muteDidChange:(NSNumber *)value {
    NSLog(@"\n%s - mute: %s", __PRETTY_FUNCTION__, value.boolValue ? "true" : "false");
}

- (void)pauseDidChange:(NSNumber *)value {
    NSLog(@"\n%s - pause: %s", __PRETTY_FUNCTION__, value.boolValue ? "true" : "false");
}

- (void)filenameDidChange:(NSString *)value {
    NSLog(@"\n%s - new filename: %@", __PRETTY_FUNCTION__, value);
}

typedef void (*methodIMP)(id, SEL, id);

- (void)player:(MPVPlayer *)player didChangeValue:(id)value forProperty:(NSString *)property format:(mpv_format)format {
    NSLog(@"\n%@ got message: %@ from: %@", self, property, player);
    
    MPVMessage *msg = _observed[property];
    if (msg) {
        methodIMP fn = (methodIMP)msg->_methodImplementation;
        fn(self, msg->_action, value);
    }
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
