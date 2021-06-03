//
//  MPVPlayerProtocol.h
//  libmpvExamples
//
//  Created by Terminator on 2021/5/22.
//  Copyright © 2021年 home. All rights reserved.
//

#import <Foundation/Foundation.h>

@protocol MPVPlayer <NSObject>
- (void)loadURL:(NSURL*)url;
- (void)shutdown;
- (BOOL)isReadyToPlay;
- (void)play;
- (void)pause;
- (void)stop;
@end
