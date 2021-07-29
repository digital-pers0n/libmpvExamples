//
//  MPVTimeFormatter.h
//  libmpvExamples
//
//  Created by Terminator on 2021/7/20.
//  Copyright © 2021年 home. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface MPVTimeFormatter : NSNumberFormatter
+ (instancetype)countdownFormatter;
- (NSString *)stringForDoubleValue:(double)time;
@end

NS_ASSUME_NONNULL_END
