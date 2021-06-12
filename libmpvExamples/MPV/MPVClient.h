//
//  MPVClient.h
//  libmpvExamples
//
//  Created by Terminator on 2021/6/1.
//  Copyright © 2021年 home. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "MPVPlayerProtocol.h"

NS_ASSUME_NONNULL_BEGIN


@interface MPVClient : NSObject<MPVPlayer>
@end

//MARK: - Properties

__attribute__((objc_direct_members))
@interface MPVClient (Properties)

- (void)setBool:(BOOL)value forName:(NSString *)propertyName;
- (void)setString:(NSString *)value forName:(NSString *)propertyName;
- (void)setInt:(int64_t)value forName:(NSString *)propertyName;
- (void)setDouble:(double)value forName:(NSString *)propertyName;

- (BOOL)boolForName:(NSString *)propertyName;
- (NSString *)stringForName:(NSString *)propertyName;
- (int64_t)intForName:(NSString *)propertyName;
- (double)doubleForName:(NSString *)propertyName;

@end

//MARK: - Commands

__attribute__((objc_direct_members))
@interface MPVClient (Commands)

// In general, "quit" command should be avoided, use -shutdown method instead.
- (void)performCommand:(NSString *)name;
- (void)performCommand:(NSString *)name arguments:(NSArray<NSString*> *)args;
- (void)performCommandString:(NSString *)cmd;
@end

__attribute__((objc_direct_members))
@interface MPVClient (Observing)
// Observers are not retained. Blocks are executed on a background queue if nil
// was passed

//MARK: - Event Observing

typedef NS_ENUM(NSUInteger, MPVEventKind) {
 //   MPVEventWillShutdown,       ///< MPV_EVENT_SHUTDOWN
    MPVEventWillStartPlayback,  ///< MPV_EVENT_START_FILE
    MPVEventDidEndPlayback,     ///< MPV_EVENT_FILE
    MPVEventDidLoadFile,        ///< MPV_EVENT_FILE_LOADED
    MPVEventDidReconfigVideo,     ///< MPV_EVENT_VIDEO_RECONFIG
    MPVEventWillStartSeeking,   ///< MPV_EVENT_SEEK
    MPVEventDidRestartPlayback, ///< MPV_EVENT_PLAYBACK_RESTART
    MPVEventAll ///< Can be used to unsubscribe from all events
};

// event is always nil for now
typedef void(^MPVObserverEventHandler)(MPVClient *mpv, id _Nullable event);

- (void)subscribe:(id)obj toEvent:(MPVEventKind)event
            queue:(nullable dispatch_queue_t)queue
          handler:(MPVObserverEventHandler)block;

- (void)subscribe:(id)observer toEvent:(MPVEventKind)event
          handler:(MPVObserverEventHandler)block;

- (void)unsubscribe:(id)observer event:(MPVEventKind)event;

//MARK: - Property Observing

typedef void(^MPVObserverBoolHandler)(MPVClient *mpv, BOOL value);
typedef void(^MPVObserverStringHandler)(MPVClient *mpv, NSString *value);
typedef void(^MPVObserverIntHandler)(MPVClient *mpv, int64_t value);
typedef void(^MPVObserverDoubleHandler)(MPVClient *mpv, double value);

- (void)subscribe:(id)observer toBool:(NSString*)prop
            queue:(nullable dispatch_queue_t)queue
          handler:(MPVObserverBoolHandler)block;

- (void)subscribe:(id)observer toString:(NSString*)prop
            queue:(nullable dispatch_queue_t)queue
          handler:(MPVObserverStringHandler)block;

- (void)subscribe:(id)observer toInt:(NSString*)prop
            queue:(nullable dispatch_queue_t)queue
          handler:(MPVObserverIntHandler)block;

- (void)subscribe:(id)observer toDouble:(NSString*)prop
            queue:(nullable dispatch_queue_t)queue
          handler:(MPVObserverDoubleHandler)block;

- (void)subscribe:(id)observer toBool:(NSString*)property
          handler:(MPVObserverBoolHandler)block;

- (void)subscribe:(id)observer toString:(NSString*)property
          handler:(MPVObserverStringHandler)block;

- (void)subscribe:(id)observer toInt:(NSString*)property
          handler:(MPVObserverIntHandler)block;

- (void)subscribe:(id)observer toDouble:(NSString*)property
          handler:(MPVObserverDoubleHandler)block;

// This is optional for observers that outlive the observed MPVClient instance.
// For observers that have shorter lifespan it depends on a handler.
// If for example, the handler accesses observer's instance variables in an
// unsafe way (e.g. unsafe_unretained) then the observer must be unsubsribed
// explicitly before deallocation.
//
- (void)unsubscribe:(id)observer property:(nullable NSString*)name;

@end

__BEGIN_DECLS
extern NSString *const MPVErrorDomain;
extern NSString *const MPVClientWillShutdownNotification;
__END_DECLS

NS_ASSUME_NONNULL_END
