//
//  MPVExampleProtocol.h
//  libmpvExamples
//
//  Created by Terminator on 2020/05/09.
//  Copyright © 2020年 home. All rights reserved.
//

#import <Foundation/Foundation.h>

@class MPVPlayer;

@protocol MPVExampleProtocol <NSObject>

@property (nonatomic, readonly) MPVPlayer * player;
- (void)destroyMPVRenderContext;

@end
