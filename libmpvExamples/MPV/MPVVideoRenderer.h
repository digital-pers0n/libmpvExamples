//
//  MPVVideoRenderer.h
//  libmpvExamples
//
//  Created by Terminator on 2021/6/28.
//  Copyright © 2021年 home. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@class MPVClient;

@protocol MPVVideoRenderer <NSObject>

- (instancetype)initWithFrame:(NSRect)rect client:(nullable MPVClient *)mpv;
@property (readonly, nonatomic) MPVClient *client;
@property (readonly, atomic, getter=isReadyForDisplay) BOOL readyForDisplay;
- (void)destroy;

@end

NS_ASSUME_NONNULL_END

