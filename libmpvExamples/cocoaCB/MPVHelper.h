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

@interface MPVHelper : NSObject

- (instancetype)initWithMpvHandle:(mpv_handle *)mpv;
@property (nonatomic) mpv_handle *mpv_handle;
@property (nonatomic) mpv_render_context *mpv_render_context;
- (void)initRender;
- (void)deinitRender;
- (void)deinitMPV:(BOOL)destroy;

@end
