//
//  MPVExampleProtocol.h
//  libmpvExamples
//
//  Created by Terminator on 2020/05/09.
//  Copyright © 2020年 home. All rights reserved.
//

#import <Foundation/Foundation.h>

@protocol MPVPlayer;

@protocol MPVExample <NSObject>
@property (nonatomic, readonly) id<MPVPlayer> player;
- (void)destroyMPVRenderContext;

@end
