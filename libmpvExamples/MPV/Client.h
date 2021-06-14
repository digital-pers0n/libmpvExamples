//
//  Client.h
//  libmpvExamples
//
//  Created by Terminator on 2021/6/14.
//  Copyright © 2021年 home. All rights reserved.
//

#ifndef Client_h
#define Client_h

#import <mpv/client.h>

namespace MPV {
struct EventLoop {
    constexpr static int Quit = 0;
    constexpr static int Wait = 1;
    
    dispatch_queue_t Queue;
    EventLoop() noexcept :
    Queue{dispatch_queue_create("mpv.event.queue", DISPATCH_QUEUE_SERIAL)} {}
    EventLoop(const EventLoop&) = delete;
    EventLoop &operator=(const EventLoop&) = delete;
    
    template<typename Fn = void(mpv_handle*, mpv_event*)>
    void start(mpv_handle *mpv, Fn didWake) const noexcept {
        dispatch_async(Queue, ^{
            while (didWake(mpv_wait_event(mpv, -1)) == Wait) {}
            puts("[EventLoop] exiting...");
        });
    }
    
    void wait() const noexcept { dispatch_sync(Queue, ^{}); }
    
}; // struct EventMonitor

constexpr mpv_format Format(double)   { return MPV_FORMAT_DOUBLE; }
constexpr mpv_format Format(bool)     { return MPV_FORMAT_FLAG;  }
constexpr mpv_format Format(int64_t)  { return MPV_FORMAT_INT64; }
constexpr mpv_format Format(int32_t)  { return MPV_FORMAT_INT64; }
constexpr mpv_format Format(int16_t)  { return MPV_FORMAT_INT64; }
constexpr mpv_format Format(uint16_t) { return MPV_FORMAT_INT64; }
constexpr mpv_format Format(uint32_t) { return MPV_FORMAT_INT64; }
constexpr mpv_format Format(const char*)     { return MPV_FORMAT_STRING; }
constexpr mpv_format Format(const mpv_node*) { return MPV_FORMAT_NODE; }
constexpr mpv_format Format(mpv_node)        { return MPV_FORMAT_NODE; }
constexpr mpv_format Format(mpv_node_list)   { return MPV_FORMAT_NODE_ARRAY; }
constexpr mpv_format Format(const mpv_node_list*) {
    return MPV_FORMAT_NODE_ARRAY;
}
inline mpv_format Format(uint64_t v) {
    return Format(v > INT64_MAX ? double(v) : int64_t(v));
}

struct Node {
    mpv_node Value{};
    Node(const mpv_node &node) noexcept : Value(node) {}
    
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wc99-designator"
    Node(double value) noexcept :
    Value{ .u.double_ = value, .format = Format(value) } {}
    Node(int64_t value) noexcept :
    Value{ .u.int64 = value, .format = Format(value) } {}
    Node(int16_t value) noexcept : Node(int64_t(value)) {}
    Node(int32_t value) noexcept : Node(int64_t(value)) {}
    Node(uint16_t value) noexcept : Node(int64_t(value)) {}
    Node(uint32_t value) noexcept : Node(int64_t(value)) {}
    Node(uint64_t v) noexcept : Node(v > INT64_MAX ? double(v) : int64_t(v)) {}
    Node(bool value) noexcept :
    Value{ .u.flag = value, .format = Format(value) } {}
    Node(const char *val, mpv_format fmt) noexcept :
    Value{ .u.string = const_cast<char*>(val), .format = fmt } {}
    Node(const char *val) noexcept : Node(val, Format(val)) {}
    Node(const mpv_node_list *val, mpv_format fmt) noexcept :
    Value{ .u.list = const_cast<mpv_node_list*>(val), .format = fmt } {}
    Node(const mpv_node_list *val) noexcept : Node(val, Format(val)) {}
#pragma clang diagnostic pop
    
    operator mpv_node() const {
        return Value;
    }
    
    operator void*() {
        return &Value;
    }
    
    operator mpv_node*() const {
        return const_cast<mpv_node*>(&Value);
    }
}; // struct Node

template<typename... Ts> struct NodeArray {
    mpv_node Values[sizeof...(Ts)]{};
    mpv_node_list List{};
    
    NodeArray(const Ts &... args) noexcept :
    Values{ Node(args)... }, List{ sizeof...(Ts), Values, nullptr } {}
    
    operator mpv_node_list() const {
        return List;
    }
    
    operator mpv_node_list*() const {
        return const_cast<mpv_node_list*>(&List);
    }
    
    operator void*() {
        return &List;
    }
}; // struct NodeArray<T>

struct Error {
    int Code{};

    bool success() const { return Code == MPV_ERROR_SUCCESS; }
    bool fail() const { return !success(); }
    operator bool() const { return fail(); }
    bool operator!() const { return success(); }
    const char *string() const { return mpv_error_string(Code); }
}; // struct Error
    
template<typename T, typename E = Error> struct Result {
    T Value{};
    E Err{};
    
    bool operator!() const { return Err; }
    operator T() const { return Value; }
    operator E() const { return Err; }
    template<typename F = void(const E&)>
    auto & operator|(F expr) const {
        if (Err) {
            expr(Err);
        }
        return *this;
    }
}; // struct Result<T>

template<typename E> struct Result<void, E> {
    E Err{};
    
    bool operator!() const { return Err; }
    operator E() const { return Err; }
    template<typename F = void(const E&)>
    auto & operator|(F expr) const {
        if (Err) {
            expr(Err);
        }
        return *this;
    }
}; // struct Result<void>

struct Client {
    template<typename Fn = void(const Client&)>
    static Result<Client> Create(Fn preinit) noexcept {
        auto handle = mpv_create();
        if (!handle) return {{handle}, {MPV_ERROR_NOMEM}};
        
        auto result = Client(handle);
        preinit(result);
        const auto error = mpv_initialize(handle);
        if (error != MPV_ERROR_SUCCESS) result.destroy();
        
        return {result, {error}};
    }
    mpv_handle *Handle{};
    Client() = default;
    Client(mpv_handle *mpv) noexcept : Handle(mpv) {}
    
    operator mpv_handle*() const {
        return const_cast<mpv_handle*>(Handle);
    }
    
    bool isValid() const { return Handle != nullptr; }
    void wakeup() const noexcept { mpv_wakeup(Handle); }

    void destroy() noexcept {
        mpv_destroy(Handle);
        Handle = nullptr;
    }
    
    // no fatal error warn info v debug trace
    Result<void> setLogLevel(const char *minLevel) const noexcept {
        return {mpv_request_log_messages(Handle, minLevel)};
    }
    
    Result<void> requestEvent(mpv_event_id kind, int enable) const noexcept {
        return {mpv_request_event(Handle, kind, enable)};
    }
    
    Result<void> enableEvent(mpv_event_id kind) const {
        return requestEvent(kind, true);
    }
    
    Result<void> disableEvent(mpv_event_id kind) const {
        return requestEvent(kind, false);
    }
    
    Result<void> subscribe(const char *propertyName, uint64_t userData,
                           mpv_format format) const noexcept
    {
        return {mpv_observe_property(Handle, userData, propertyName, format)};
    }
    
    Result<void> unsubscribe(uint64_t userData) const noexcept {
        return {mpv_unobserve_property(Handle, userData)};
    }
    
    template<typename T, typename F = void(const char *key, T value, Error e)>
    auto & setValue(const T &value, const char *key, F didFail) const noexcept {
        if (const auto ok = setValue(value, key); !ok) {
            didFail(key, value, ok.Err);
        }
        return *this;
    }
    
    template<typename T>
    Result<void> setValue(const T &value, const char *key) const noexcept {
        auto node = Node(value);
        return {mpv_set_property(Handle, key, MPV_FORMAT_NODE, &node)};
    }
    
    template<typename T>
    Result<T> value(const char *key) const noexcept {
        T result{};
        const auto e = mpv_get_property(Handle, key, Format(result), &result);
        return {result, e};
    }
    
    Result<void> perform(const mpv_node_list *args) const noexcept {
        const auto node = Node(args);
        return {mpv_command_node(Handle,  node, /*result*/{})};
    }
    
    template<typename ...Ts>
    Result<void> perform(const char* cmd, const Ts &... args) const noexcept {
        const auto array = NodeArray(cmd, args...);
        return perform(array);
    }
    
    Result<void> perform(const char **args) const noexcept {
        return {mpv_command(Handle, args)};
    }
    
    Result<void> performString(const char *cmd) const noexcept {
        return {mpv_command_string(Handle, cmd)};
    }
    
    Result<void> quit() const {
        return perform("quit");
    }
    
    Result<void> pause(bool flag) const {
        return setValue(flag, "pause");
    }
    
    Result<void> pause() const {
        return pause(true);
    }
    
    Result<void> play() const {
        return pause(false);
    }
    
    Result<void> stop() const {
        return perform("stop");
    }
    
    Result<void> loadFile(const char *path) const {
        return perform("loadfile", path);
    }
    
}; // struct Client
} // namespace MPV

#endif /* Client_h */
