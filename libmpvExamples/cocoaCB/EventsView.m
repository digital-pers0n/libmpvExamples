//
//  EventsView.m
//  libmpvExamples
//
//  Created by Terminator on 2019/08/01.
//  Copyright © 2019年 home. All rights reserved.
//

#import "EventsView.h"
#import "MPVHelper.h"
#import "CocoaCB.h"
#import "Window.h"

@implementation EventsView

- (MPVHelper *)mpv {
    return _cocoaCB.mpv;
}

#pragma mark - Init

- (instancetype)initWithCocoaCB:(CocoaCB *)ccb {
    _cocoaCB = ccb;
    self = [super initWithFrame:NSMakeRect(0, 0, 960, 480)];
    if (self) {
        self.autoresizingMask = NSViewWidthSizable | NSViewHeightSizable;
        self.wantsBestResolutionOpenGLSurface = YES;
        [self registerForDraggedTypes:@[(id)kUTTypeFileURL, (id)kUTTypeURL]];
    }
    return self;
}

#pragma mark - Overrides

- (BOOL)isFlipped {
    return YES;
}

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

- (void)updateTrackingAreas {
    [super updateTrackingAreas];
    if (_tracker) {
        [self removeTrackingArea:_tracker];
    }
    _tracker = [NSTrackingArea.alloc
                initWithRect:self.bounds
                options:
                NSTrackingActiveAlways |
                NSTrackingMouseEnteredAndExited |
                NSTrackingMouseMoved |
                NSTrackingEnabledDuringMouseDrag
                owner:self
                userInfo:nil];
    [self addTrackingArea:_tracker];
}

- (void)mouseEntered:(NSEvent *)theEvent {
    [_cocoaCB.window showTitleBar];
}

- (void)mouseExited:(NSEvent *)theEvent {
    [_cocoaCB.window hideTitleBar];
}

- (void)mouseMoved:(NSEvent *)theEvent {
    // [_cocoaCB.window showTitleBar];
}

#pragma mark - Drag n Drop

- (NSDragOperation)draggingEntered:(id<NSDraggingInfo>)sender {
    NSArray *types = sender.draggingPasteboard.types;
    if ([types containsObject:(id)kUTTypeFileURL] || [types containsObject:(id)kUTTypeURL]) {
        return NSDragOperationCopy;
    }
    return NSDragOperationNone;
}

// TODO: Implement Drag n Drop
- (BOOL)performDragOperation:(id<NSDraggingInfo>)sender {
    return NO;
}

#pragma mark - Draw

- (void)drawRect:(NSRect)dirtyRect {

}

@end
