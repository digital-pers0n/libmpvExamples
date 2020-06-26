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

- (void)loadFile:(NSURL *)url {
    const char *cmd[] = { "loadfile", url.fileSystemRepresentation, NULL };
    mpv_command(_cocoaCB.mpv.mpv_handle, cmd);
}

#pragma mark - Overrides

- (BOOL)mouseDownCanMoveWindow {
    return YES;
}

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

- (void)keyDown:(NSEvent *)theEvent {
    NSString *chars = theEvent.charactersIgnoringModifiers;
    const char *cmd[] = { "keydown", chars.UTF8String, NULL };
    mpv_command(_cocoaCB.mpv.mpv_handle, cmd);
}

- (void)keyUp:(NSEvent *)theEvent {
    NSString *chars = theEvent.characters;
    const char *cmd[] = { "keyup", chars.UTF8String, NULL };
    mpv_command(_cocoaCB.mpv.mpv_handle, cmd);
}

#pragma mark - Drag n Drop

- (NSDragOperation)draggingEntered:(id<NSDraggingInfo>)sender {
    NSArray *types = sender.draggingPasteboard.types;
    if ([types containsObject:(id)kUTTypeFileURL] || [types containsObject:(id)kUTTypeURL]) {
        return NSDragOperationCopy;
    }
    return NSDragOperationNone;
}

- (BOOL)performDragOperation:(id<NSDraggingInfo>)sender {
    
    NSPasteboard *pb = sender.draggingPasteboard;
    NSArray *array = [pb readObjectsForClasses:@[NSURL.class] options:nil];
    if (array.count) {
        NSURL *url = array.firstObject;
        if ([url isFileReferenceURL]) {
            url = [url filePathURL];
        }
        [self loadFile:url];
        return YES;
    }
    
    array = [pb readObjectsForClasses:@[NSString.class] options:nil];
    if (array.count) {
        NSURL *url = [NSURL URLWithString:array.firstObject];
        if (url) {
            [self loadFile:url];
            return YES;
        }
        
        url = [NSURL fileURLWithPath:array.firstObject];
        if (url) {
            [self loadFile:url];
            return YES;
        }
    }
    return NO;
}

#pragma mark - Draw

- (void)drawRect:(NSRect)dirtyRect {

}

@end
