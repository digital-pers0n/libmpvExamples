//
//  MPVClient.m
//  libmpvExamples
//
//  Created by Terminator on 2021/6/1.
//  Copyright © 2021年 home. All rights reserved.
//

#import "MPVClient.h"
#import "Client.h"

extern "C" {
NSString *const MPVErrorDomain = @"com.example.mpv.client.ErrorDomain";
NSString *const MPVClientWillShutdownNotification = @"MPVClientWillShutdown";
}

#define MPVErrorLog(e, fmt, ...) \
NSLog(@fmt " (code: %i, info: %s)", ##__VA_ARGS__, e.Code, e.string())

#define MPVGenericError(fmt, ...) \
[&](const MPV::Error &e) { \
MPVErrorLog(e, "[MPVClient] Error: " fmt, ##__VA_ARGS__); \
}

#define MPVCommandError(cmd, arg) \
MPVGenericError("command: '%@' args: '%@'", cmd, arg)

#define MPVCommandStringError(cmd) \
MPVGenericError("command: '%@'", cmd)

#define MPVSetValueError(fmt, value, name) \
MPVGenericError("Failed to set value: '" fmt "' for '%@'", value, name)

#define MPVGetValueError(err, type, name) \
MPVErrorLog(err, "[MPVClient] Error: Failed to get " type " value for '%@'", name)

@interface NSMutableArray (MPVClientAdditions) @end

[[clang::objc_direct_members]]
@implementation NSMutableArray (MPVClientAdditions)

- (void)removeSubscriber:(id)item {
    const auto idx = [self indexOfObjectPassingTest:
    ^BOOL(id  _Nonnull obj, NSUInteger, BOOL*) { return (obj == item); }];
    if (idx != NSNotFound) {
        [self removeObjectAtIndex:idx];
    }
}

@end

@interface MPVSubscriber : NSObject @end

[[clang::objc_direct_members]]
@implementation MPVSubscriber {
@package struct {
    template<typename T, typename U>
    using NotifyHandler = void(^)(T, U);
    dispatch_queue_t Queue;
    id Handler;
    
    template<typename T, typename U>
    void operator()(T client, U obj) const noexcept {
        if (!Queue) {
            return ((NotifyHandler<T, U>)Handler)(client, obj);
        }
        dispatch_async(Queue, ^{
            ((NotifyHandler<T, U>)Handler)(client, obj);
        });
    }
} _notifier; }

- (instancetype)initWithQueue:(nullable dispatch_queue_t)q
                      handler:(nonnull id)block
{
    if (!(self = [super init])) return nil;
    _notifier.Queue = q;
    _notifier.Handler = block;
    return self;
}
- (instancetype)init { return [self initWithQueue:nil handler:^(id,id){}]; }
@end

namespace {
    
MPVSubscriber *MPVSubscriberCreate(dispatch_queue_t q, id task) noexcept {
    return [[MPVSubscriber alloc] initWithQueue:q handler:task];
}
    
struct Publisher {
    template<typename U, typename T> using NotifyHandler = void(^)(U, T);

    dispatch_queue_t Queue;
    
    // [ context(unretained): [ propertyName: MPVSubscriber ]]
    NSMapTable<id, NSMutableDictionary<NSString*, id>*> *Subscribers;
    
    // [ handler(unretained) ]
    NSHashTable *Cache;
    
    NSMapTable<id, NSPointerArray*> *EventSubscribers;
    NSMutableArray *EventCache[MPVEventAll];
    
    Publisher() = default;
    Publisher(const Publisher &) = delete;
    Publisher &operator=(const Publisher &) = delete;
    
    void init() noexcept {
        Queue = dispatch_queue_create("mpv.publisher.queue",
                                      DISPATCH_QUEUE_SERIAL);
        
        const auto keys = (NSPointerFunctionsOpaqueMemory |
                           NSPointerFunctionsOpaquePersonality);
        const auto vals = (NSPointerFunctionsStrongMemory |
                           NSPointerFunctionsObjectPersonality);
        
        Subscribers = [[NSMapTable alloc] initWithKeyOptions:keys
                                                valueOptions:vals capacity:1];
        Cache = [[NSHashTable alloc] initWithOptions:keys capacity:1];
        
        EventSubscribers = [Subscribers copy];
        for (auto &item : EventCache) {
            item = [[NSMutableArray alloc] init];
        }
    }
    
    void async(dispatch_block_t task) const noexcept {
        dispatch_async(Queue, task);
    }
    
    void sync(dispatch_block_t task) const noexcept {
        dispatch_sync(Queue, task);
    }
    
//MARK: - Event Observing
    template<typename Fn = void(const Publisher &)>
    void subscribe(id ctx, MPVEventKind eventID,
                   dispatch_queue_t queue, id task, Fn done) const noexcept {
        async(^{
            subscribe(ctx, eventID, MPVSubscriberCreate(queue, task), done);
        });
    }
    
    template<typename Fn = void(const Publisher &)>
    void subscribe(id ctx, MPVEventKind eventId, MPVSubscriber *task, Fn done)
    const noexcept {
        NSCAssert(eventId < MPVEventAll, @"Bad event kind: %zu", eventId);
        auto subscribers = EventSubscribers;
        auto cache = EventCache[eventId];
        auto subscribed = [subscribers objectForKey:ctx];
        if (!subscribed) {
            auto array = [[NSPointerArray alloc] initWithOptions:
                          NSPointerFunctionsStrongMemory |
                          NSPointerFunctionsObjectPersonality];
            array.count = MPVEventAll;
            [array replacePointerAtIndex:eventId
                             withPointer:(__bridge void*)task];
            [cache addObject:task];
            return [subscribers setObject:array forKey:ctx];
        }
        id handler = (__bridge id)[subscribed pointerAtIndex:eventId];
        if (handler) {
            [cache removeSubscriber:handler];
        }
        
        [subscribed replacePointerAtIndex:eventId
                              withPointer:(__bridge void*)task];
        [cache addObject:task];
        done(*this);
    }
    
    template<typename Fn = void(const Publisher &)>
    void unsubscribe(id ctx, MPVEventKind eventId, Fn done) const noexcept {
        async(^{
            auto subscribers = EventSubscribers;
            auto subscribed = [subscribers objectForKey:ctx];
            NSCAssert(subscribed, @"%@ is not a subscriber!", ctx);
            
            if (eventId == MPVEventAll) {
                for (id item in subscribed) {
                    if (!item) continue;
                    for (const auto &cache : EventCache) {
                        [cache removeSubscriber:item];
                    }
                }
                subscribed.count = 0;
                subscribed.count = MPVEventAll;
                return;
            }
            id item = (__bridge id)[subscribed pointerAtIndex:eventId];
            NSCAssert(item, @"%@ is not a subscriber!", ctx);
            [EventCache[eventId] removeSubscriber:item];
            [subscribed replacePointerAtIndex:eventId withPointer:nullptr];
            done(*this);
        });
    }
    
    template<MPVEventKind Event, typename T, typename U>
    void notify(T client, U value) const noexcept {
        static_assert(Event < MPVEventAll, "Bad event kind");
        
        auto cache = EventCache[Event];
        async(^{
            for (MPVSubscriber *item in cache) {
                item->_notifier(client, value);
            }
        });
    }
    
    NSUInteger numberOfEventSubscribers(MPVEventKind eventId) const noexcept {
        return EventCache[eventId].count;
    }
    
//MARK: - Property Observing
    
    void subscribe(const MPV::Client mpv, id ctx, NSString *name,
                   mpv_format fmt, dispatch_queue_t q, id task) const noexcept {
        async(^{
            subscribe(mpv, ctx, name, fmt, MPVSubscriberCreate(q, task));
        });
    }
    
    void subscribe(const MPV::Client mpv, id context, NSString *name,
                    mpv_format fmt, MPVSubscriber *task) const noexcept {
        auto subscribers = Subscribers;
        auto cache = Cache;

        const MPV::Error e = mpv.subscribe(name.UTF8String,
                                      reinterpret_cast<uint64_t>(task), fmt);
        if (e) {
            return MPVErrorLog(e, "[Publisher] Failed to add subscriber '%@' "
                               "for '%@'", context, name);
        }
        
        // check if a given context has any subscribed handlers
        auto subscribed = [subscribers objectForKey:context];
        if (!subscribed) {
            // create a new dictionary to hold handlers
            auto dict = [[NSMutableDictionary alloc]
                         initWithObjects:(id[]){task}
                                 forKeys:(id[]){name} count:1];
            
            [subscribers setObject:dict forKey:context];
            return [cache addObject:task];
        }
        
        // check if a handler was previously subscribed to a given name
        if (id handler = [subscribed objectForKey:name]; handler != nil) {
            // unsubscribe and remove the old handler
            mpv.unsubscribe(reinterpret_cast<uint64_t>(handler));
            [cache removeObject:handler];
        }
        [subscribed setObject:task forKey:name];
        [cache addObject:task];
    }
    
    void unsubscribe(const MPV::Client mpv, id context, NSString *name)
    const noexcept {
        async(^{
            auto subscribers = Subscribers;
            auto cache = Cache;
            
            auto subscribed = [subscribers objectForKey:context];
            
            if (name) {
                id handler = [subscribed objectForKey:name];
                mpv.unsubscribe(reinterpret_cast<uint64_t>(handler));
                [cache removeObject:handler];
                [subscribed removeObjectForKey:name];
                return;
            }
            
            for (id handler in subscribed.allValues) {
                mpv.unsubscribe(reinterpret_cast<uint64_t>(handler));
                [cache removeObject:handler];
            }
            [subscribers removeObjectForKey:context];
        });
    }
    
    template<typename T> void
    notify(T ctx, mpv_event_property *prop, void *data) const noexcept {
        auto notifier = [&](const auto value) {
            notify(ctx, value, data);
        };
        switch (prop->format) {
            case MPV_FORMAT_FLAG:
                notifier(*(reinterpret_cast<BOOL*>(prop->data)));
                break;
            case MPV_FORMAT_INT64:
                notifier(*(reinterpret_cast<int64_t*>(prop->data)));
                break;
            case MPV_FORMAT_DOUBLE:
                notifier(*(reinterpret_cast<double*>(prop->data)));
                break;
            case MPV_FORMAT_STRING:
                notifier(@(*(reinterpret_cast<char**>(prop->data))));
                break;
            default:
                NSLog(@"[Publisher] Failed to handle update for '%s' property. "
                      "Unsupported format: %i", prop->name, prop->format);
                break;
        }
    }
    
    template<typename T, typename U> void
    notify(T ctx, const U value, void *item) const noexcept {
        async(^{
            if (!verify(item)) return;
            ((__bridge MPVSubscriber*)item)->_notifier(ctx, value);
        });
    }
    
    bool verify(void *block) const noexcept {
        return [Cache containsObject:(__bridge id __unsafe_unretained)block];
    }
    
}; // struct Publisher
    
[[gnu::cold]] NSError *
MPVCreateError(const MPV::Error &err, NSString *desc, NSString *sug) noexcept {
    id info = @{ NSLocalizedRecoverySuggestionErrorKey : sug,
                 NSLocalizedDescriptionKey: [desc stringByAppendingFormat:
                                             @" (%s)", err.string()]};
    return [NSError errorWithDomain:MPVErrorDomain code:err.Code userInfo:info];
}

const auto MPVPropertyErrorLog =
[](const char *key, const auto &value, const MPV::Error &e) {
    NSLog(@"[MPVClient] Failed to set value '%@' for '%s': (%i, %s)",
          @(value), key, e.Code, e.string());
};
    
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wc99-designator"
    
constexpr mpv_event_id LibMPVEventTable[] = {
    [MPVEventWillStartPlayback] = MPV_EVENT_START_FILE,
    [MPVEventDidEndPlayback] = MPV_EVENT_END_FILE,
    [MPVEventDidLoadFile] = MPV_EVENT_FILE_LOADED,
    [MPVEventDidReconfigVideo] = MPV_EVENT_VIDEO_RECONFIG,
    [MPVEventWillStartSeeking] = MPV_EVENT_SEEK,
    [MPVEventDidRestartPlayback] = MPV_EVENT_PLAYBACK_RESTART,
};
    
#pragma clang diagnostic pop
    
constexpr MPVEventKind MPVExcludableEventTable[] = {
    MPVEventWillStartPlayback, MPVEventDidEndPlayback,
    MPVEventDidLoadFile, MPVEventDidReconfigVideo,
    MPVEventWillStartSeeking, MPVEventDidRestartPlayback,
};
    
} // anonymous namespace

[[clang::objc_direct_members]]
@interface MPVClient ()
@property (atomic) BOOL initialized;
@end

[[clang::objc_direct_members]]
@implementation MPVClient {
    MPV::Client _mpv;
    MPV::EventLoop _eventLoop;
    Publisher _publisher;
    NSError *_error;
    BOOL _initialized;
}

- (instancetype)init {
    return [self initWithBlock:^(id){}];
}

- (instancetype)initWithBlock:(void(^)(MPVClient*))preinit {
    if (!(self = [super init])) return nil;
    const auto res = MPV::Client::Create([&](const MPV::Client &r) {
        const auto &errLog = MPVPropertyErrorLog;
        r.setValue("videotoolbox", "hwdec", errLog)
        .setValue(true, "keep-open", errLog)
        .setValue(true, "input-default-bindings", errLog)
        .setValue("libmpv", "vo", errLog)
        .setValue(70, "volume", errLog)
        .setLogLevel("warn");
        
        _mpv = r;
        preinit(self);
    });
    
    if (!res) {
        _mpv = {};
        _error = MPVCreateError(res.Err, @"Failed to intialize mpv.",
                                @"Incorrect parameters or out of memory.");
    } else {
        for (const auto &event : MPVExcludableEventTable) {
            _mpv.disableEvent(LibMPVEventTable[event]);
        }
        
        _publisher.init();
        [self startEventLoop];
        self.initialized = YES;
    }
    return self;
}

- (void)dealloc {
    [self shutdown];
}

//MARK: - Event Loop

- (void)startEventLoop {
    __unsafe_unretained auto u = self;
    _eventLoop.start(_mpv, [=](mpv_event *ev) {
        switch (ev->event_id) {
        case MPV_EVENT_NONE:
        case MPV_EVENT_SHUTDOWN:
            puts("[MPVClient] shutting down...");
//            dispatch_async(dispatch_get_main_queue(), ^{
//                if (!u->_initialized) return;
//                [u shutdown];
//            });
            return MPV::EventLoop::Quit;
                
        case MPV_EVENT_LOG_MESSAGE: {
            const auto msg = reinterpret_cast<mpv_event_log_message*>(ev->data);
            printf("[%s]  %s : %s", msg->prefix, msg->level, msg->text);
        }
            break;
                
        case MPV_EVENT_START_FILE:
            u->_publisher.notify<MPVEventWillStartPlayback>(u, nil);
            break;
            
        case MPV_EVENT_END_FILE:
            u->_publisher.notify<MPVEventDidEndPlayback>(u, nil);
            break;
            
        case MPV_EVENT_FILE_LOADED:
             u->_publisher.notify<MPVEventDidLoadFile>(u, nil);
            break;
            
        case MPV_EVENT_VIDEO_RECONFIG:
             u->_publisher.notify<MPVEventDidReconfigVideo>(u, nil);
            break;
            
        case MPV_EVENT_SEEK:
             u->_publisher.notify<MPVEventWillStartSeeking>(u, nil);
            break;
            
        case MPV_EVENT_PLAYBACK_RESTART:
             u->_publisher.notify<MPVEventDidRestartPlayback>(u, nil);
            break;
            
        case MPV_EVENT_PROPERTY_CHANGE: {
            const auto prop = reinterpret_cast<mpv_event_property*>(ev->data);
            const auto data = reinterpret_cast<void*>(ev->reply_userdata);
#if DEBUG
            printf("[MPVClient] did change property '%s', format: %i, "
                   "user_data: %llx, error: %s\n", prop->name, prop->format,
                   ev->reply_userdata, mpv_error_string(ev->error));
#endif
            // ignore MPV_FORMAT_NONE for now
            if (prop->format == MPV_FORMAT_NONE) break;
            u->_publisher.notify(u, prop, data);
        }
            break;
        default:
            printf("[MPVClient] %s\n", mpv_event_name(ev->event_id));
            u->_mpv.disableEvent(ev->event_id) |
                MPVGenericError("disableEvent()");
            break;
        }
        return MPV::EventLoop::Wait;
    });
}

//MARK: - MPVPlayer Protocol

- (void)loadURL:(NSURL *)url {
    _mpv.loadFile(url.absoluteString.UTF8String);
}

- (void)play {
    _mpv.play();
}

- (void)pause {
    _mpv.pause();
}

- (void)stop {
    _mpv.stop();
}

- (void)shutdown {
    if (!_initialized) return;
    self.initialized = NO;
    _mpv.quit();
    _eventLoop.wait();
    [NSNotificationCenter.defaultCenter
     postNotificationName:MPVClientWillShutdownNotification object:self];
    _mpv.destroy();
}

- (BOOL)isReadyToPlay {
    return _initialized;
}

@end

//MARK: - Properties

@implementation MPVClient (Properties)

- (void)setBool:(BOOL)v forName:(NSString *)prop {
    _mpv.setValue(bool(v), prop.UTF8String) | MPVSetValueError("%i", v, prop);
}

- (void)setString:(NSString *)val forName:(NSString *)prop {
    _mpv.setValue(val, prop.UTF8String) | MPVSetValueError("%@", val, prop);
}

- (void)setInt:(int64_t)val forName:(NSString *)prop {
    _mpv.setValue(val, prop.UTF8String) | MPVSetValueError("%lli", val, prop);
}

- (void)setDouble:(double)val forName:(NSString *)prop {
    _mpv.setValue(val, prop.UTF8String) | MPVSetValueError("%f", val, prop);
}

- (BOOL)boolForName:(NSString *)property {
    auto result = _mpv.value<bool>(property.UTF8String);
    if (!result) {
        MPVGetValueError(result.Err, "bool", property);
    }
    return result;
}

- (NSString *)stringForName:(NSString *)property {
    const auto result = _mpv.value<char*>(property.UTF8String);
    if (!result) {
        MPVGetValueError(result.Err, "string", property);
        return nil;
    }
    auto string = @(result.Value);
    mpv_free(result.Value);
    return string;
}
- (int64_t)intForName:(NSString *)property {
    auto result = _mpv.value<int64_t>(property.UTF8String);
    if (!result) {
        MPVGetValueError(result.Err, "int", property);
    }
    return result;
}
- (double)doubleForName:(NSString *)property {
    auto result = _mpv.value<double>(property.UTF8String);
    if (!result) {
        MPVGetValueError(result.Err, "double", property);
    }
    return result;
}

@end

//MARK: - Commands

[[clang::objc_direct_members]]
@implementation MPVClient (Commands)

- (void)performCommand:(NSString *)name {
    _mpv.perform(name.UTF8String) | MPVCommandStringError(name);
}

- (void)performCommand:(NSString *)name arguments:(NSArray<NSString*>*)args {
    const auto count = args ? args.count : 0;
    auto cmdErr = MPVCommandError(name, args);
    
    switch (count) { // unroll the loop for a small number of args
    case 0:
        _mpv.perform(name.UTF8String) | cmdErr;
        return;
    case 1:
        _mpv.perform(name.UTF8String, args[0].UTF8String) | cmdErr;
        return;
    case 2:
        _mpv.perform(name.UTF8String, args[0].UTF8String,
                     args[1].UTF8String) | cmdErr;
        return;
            
    default:
        [self performCommand:name arguments:args count:count];
        break;
    }
}

- (void)performCommand:(NSString *)name arguments:(NSArray<NSString*> *)args
                 count:(NSUInteger)size
{
    auto buf = static_cast<const char**>(calloc(size + 2, sizeof(char*)));
    buf[0] = name.UTF8String;
    size_t idx = 1;
    for (NSString *obj in args) { buf[idx++] = obj.UTF8String; }
    
    _mpv.perform(buf) | MPVCommandError(name, args);
    free(buf);
}

- (void)performCommandString:(NSString *)cmd {
    _mpv.performString(cmd.UTF8String) | MPVCommandStringError(cmd);
}

@end

[[clang::objc_direct_members]]
@implementation MPVClient (Observing)
//MARK: Event Observing

- (void)subscribe:(id)obj toEvent:(MPVEventKind)event queue:(dispatch_queue_t)q
          handler:(MPVObserverEventHandler)task
{
    if (event == MPVEventAll) return;
    
    _publisher.subscribe(obj, event, q, [task copy],
     [=, &mpv = _mpv](const Publisher &publisher) {
         if (publisher.numberOfEventSubscribers(event) == 1) {
             mpv.enableEvent(LibMPVEventTable[event]);
         }
     });
}

- (void)subscribe:(id)obj toEvent:(MPVEventKind)event
          handler:(MPVObserverEventHandler)block {
    [self subscribe:obj toEvent:event queue:nil handler:block];
}

- (void)unsubscribe:(id)obj event:(MPVEventKind)event {
    _publisher.unsubscribe(obj, event,
    [=, &mpv = _mpv](const Publisher &publisher) {
        auto disableEvent = [&](MPVEventKind ev) {
            if (publisher.numberOfEventSubscribers(ev) == 0) {
                mpv.disableEvent(LibMPVEventTable[ev]);
            }
        };
        if (event == MPVEventAll) {
            for (const auto &ev : MPVExcludableEventTable) {
                disableEvent(ev);
            }
        } else {
            disableEvent(event);
        }
    });
}

//MARK: Property Observing

- (void)subscribe:(id)obj toBool:(NSString*)prop queue:(dispatch_queue_t)queue
          handler:(MPVObserverBoolHandler)task {
    _publisher.subscribe(_mpv, obj, prop, MPV_FORMAT_FLAG, queue, [task copy]);
}

- (void)subscribe:(id)obj toString:(NSString*)prop queue:(dispatch_queue_t)queue
          handler:(MPVObserverStringHandler)task {
    _publisher.subscribe(_mpv, obj, prop, MPV_FORMAT_STRING, queue, [task copy]);
}

- (void)subscribe:(id)obj toInt:(NSString*)prop queue:(dispatch_queue_t)queue
          handler:(MPVObserverIntHandler)task {
    _publisher.subscribe(_mpv, obj, prop, MPV_FORMAT_INT64, queue, [task copy]);
}

- (void)subscribe:(id)obj toDouble:(NSString*)prop queue:(dispatch_queue_t)queue
          handler:(MPVObserverDoubleHandler)task {
    _publisher.subscribe(_mpv, obj, prop, MPV_FORMAT_DOUBLE, queue, [task copy]);
}

- (void)subscribe:(id)obj toBool:(NSString*)prop
          handler:(MPVObserverBoolHandler)task {
    [self subscribe:obj toBool:prop queue:nil handler:task];
}

- (void)subscribe:(id)obj toString:(NSString*)prop
          handler:(MPVObserverStringHandler)task {
    [self subscribe:obj toString:prop queue:nil handler:task];
}

- (void)subscribe:(id)obj toInt:(NSString*)prop
          handler:(MPVObserverIntHandler)task {
    [self subscribe:obj toInt:prop queue:nil handler:task];
}

- (void)subscribe:(id)obj toDouble:(NSString*)prop
          handler:(MPVObserverDoubleHandler)task {
    [self subscribe:obj toDouble:prop queue:nil handler:task];
}

- (void)unsubscribe:(id)obj property:(NSString*)name {
    _publisher.unsubscribe(_mpv, obj, name);
}

@end
