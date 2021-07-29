//
//  MPVTimeFormatter.mm
//  libmpvExamples
//
//  Created by Terminator on 2021/7/20.
//  Copyright © 2021年 home. All rights reserved.
//

#import "MPVTimeFormatter.h"

namespace {
struct MPVTime {
    constexpr static uint64_t Max = 3600ULL * 999 + 60 * 59 + 59;
    uint64_t Hours, Minutes, Seconds;
    MPVTime(uint64_t time) noexcept : Hours{time / 3600},
        Minutes{(time % 3600) / 60}, Seconds{(time % 3600) % 60} {}
    MPVTime(double time) noexcept : MPVTime(uint64_t(fmin(time, Max))) {}
    
    enum struct Style { Normal, Countdown };
    template<Style Kind = Style::Normal>
    static CFStringRef String(double value) noexcept {
        if (value < 1.0) return CFSTR("00:00:00");
        const auto &[h, m, s] = MPVTime(value);
        const auto fmt = (Kind == Style::Countdown)
            ? CFSTR("-%02llu:%02llu:%02llu") : CFSTR( "%02llu:%02llu:%02llu");
        return CFStringCreateWithFormat(kCFAllocatorDefault, {}, fmt, h, m, s);
    }
}; // struct MPVTime
} // anonymous namespace

@interface MPVCountdownTimeFormatter : MPVTimeFormatter @end

@implementation MPVTimeFormatter

+ (instancetype)countdownFormatter {
    return [MPVCountdownTimeFormatter new];
}

- (NSString *)stringForDoubleValue:(double)num {
    return CFBridgingRelease(MPVTime::String(num));
}

- (NSString *)stringForObjectValue: obj {
    NSParameterAssert([obj respondsToSelector:@selector(doubleValue)]);
    return CFBridgingRelease(MPVTime::String([obj doubleValue]));
}

@end

@implementation MPVCountdownTimeFormatter

- (NSString *)stringForDoubleValue:(double)num {
    return CFBridgingRelease(MPVTime::String<MPVTime::Style::Countdown>(num));
}

- (NSString *)stringForObjectValue: obj {
    NSParameterAssert([obj respondsToSelector:@selector(doubleValue)]);
    return CFBridgingRelease
    (MPVTime::String<MPVTime::Style::Countdown>([obj doubleValue]));
}

@end
