//
//  MPVHelper.h
//  libmpvExamples
//
//  Created by Terminator on 2019/08/01.
//  Copyright © 2019年 home. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <mpv/client.h>
#import <mpv/render_gl.h>
#import "MPVPlayerProtocol.h"

@interface MPVHelper : NSObject<MPVPlayer>

- (instancetype)initWithMpvHandle:(mpv_handle *)mpv;
@property (nonatomic) mpv_handle *mpv_handle;
@property (nonatomic) mpv_render_context *mpv_render_context;

- (void)initRender;
- (void)deinitRender;
- (void)deinitMPV:(BOOL)destroy;

- (void)setRenderUpdateCallback:(mpv_render_update_fn)callback context:(id)object;
- (void)reportRenderFlip;
- (void)drawRender:(NSSize)surface;

- (BOOL)getBoolProperty:(NSString *)name;
- (NSInteger)getIntProperty:(NSString *)name;
- (NSString *)getStringProperty:(NSString *)name;

@end
