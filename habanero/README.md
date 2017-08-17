Habanero
========
Open repo with some useful stuff I produce sometimes.
Mostly C++ based and oriented for Mac(MacOSX/OSX/macOS) working environment (some stuff might work on iOS-based OSes as well).
This code is C++14 with some intrusions of coming C++17 via std::experimental.
The library also assumes x64 build targets.
[Nimble Commander](http://magnumbytes.com/) uses this code extensively.

Habanero/CFDefaultsCPP.h
-----------
Routines to work with User Defaults (CFPreferences / NSUserDefaults) directly and safely from C++. There're variants to get value directly, regardless of it's presence, or to get it via optional<> to check if it is actually present in defaults map. Example:
```C++
if( auto v = CFDefaultsGetOptionalString( CFSTR("MySetting") ) )
  cout << "existing setting: " << *v << endl;
else 
  CFDefaultsSetString( CFSTR("MySetting"), "42!" );
```

Habanero/CFStackAllocator.h
-----------
It's stack-based allocator for CoreFoundation objects. Might be useful for fast creating and processing some small objects, like CFStringRef. Obviously, object allocated with CFStackAllocator should not leak outside the function it was created in,
since this will lead to crash. CFStackAllocator is much faster than stock CoreFoundation allocator, but should be used with care.

Habanero/CFString.h
-----------
Set of routines for CFStringRef<->std::string interop.
Also has a CFString C++ class, which makes owning of CFStringRef objects a bit easier.

Habanero/CommonPaths.h
-----------
Some routines to access persistent directory locations. Contained in CommonPaths:: namespace.

Habanero/dispatch_cpp.h
-----------
A set of functions providing modern C++ interface for libdispatch API (also known as gcd - Grand Cental Dispatch).
They use C++11 lambdas as a callbacks and std::chrono values, so you can write something like this:
```C++
dispatch_after( 10s, dispatch_get_main_queue(), []{ cout << "ten seconds after..." << end; } );
```
Following functions are wrapped and are available with the same names via C++ overloading resolution:
  * dispatch_async
  * dispatch_sync
  * dispatch_apply
  * dispatch_after
  * dispatch_barrier_async
  * dispatch_barrier_sync

Also some useful additions include these:
  * dispatch_is_main_queue
  * dispatch_assert_main_queue
  * dispatch_assert_background_queue
  * dispatch_to_main_queue
  * dispatch_to_default
  * dispatch_to_background
  * dispatch_to_main_queue_after
  * dispatch_to_background_after
  * dispatch_or_run_in_main_queue

Habanero/DispatchGroup.h
-----------
High-level wrapper abstraction on top of GCD's dispatch_group_async() - an execution group, with callback signals about group's load state and info about amount of currently running tasks. Like dispatch_cpp.h, DispatchGroup is compatible with C++ lambdas and function<>'s.
```C++
DispatchGroup dg;
dg.SetOnDry( []{ cout << "omg what have we done!"; } );
dg.Run( []{ /* launch missiles */ } );
dg.Run( []{ /* estimate fallout at the same time */ } );
dg.Wait();
```

Habanero/GoogleAnalytics.h
-----------
Yet another Google Analytics client, this time for C++/macOS platform. Supposed to work fast and perform sending in background thread. By default this service is disabled, it's availability is controlled by boolean GoogleAnalytics::g_DefaultsTrackingEnabledKey user defaults key. Requires Boost. General idea of usage:
```C++
// Init singleton somewhere
GoogleAnalytics& GA()
{
    static auto inst = new GoogleAnalytics( "UA-XXXXXXXX-X" );
    return *inst;
}
// Call upon some event
GA().PostEvent("Some Event Category", "Some Event Action", "Some Event Label");
```

Habanero/Hash.h
-----------
Hash/checksum calculation facility, supporting Adler32/CRC32/MD2/MD4/MD5/SHA1_160/SHA2_224/SHA2_256/SHA2_384/SHA2_512.
Relies on zlib and CommonCrypto routines.

Habanero/IdleSleepPreventer.h
-----------
IdleSleepPreventer class, which provides RAII-style interface for MacOSX's IOKit to prevent system sleep while app is doing something meaningful:
```C++
{
auto insomnia_promise = IdleSleepPreventer::Instance().GetPromise();
// perform task for a long time
}
```

Habanero/mach_time.h
-----------
Provides std::chrono::nanoseconds machtime() function, which tells the current relative kernel time in safe form of std::chrono. Also has a tiny MachTimeBenchmark time-measuring facility.

Habanero/Observable.h
-----------
Provides a generic thread-safe events observation facility. Client's subscription yields a RAII-style ObservationTicket, which unsubscribe client upon destruction. Event's can be identified and fired via bit mask, so up to 64 event types can be set up. ObservableBase interface may be entered from callbacks. General usage principle follows this scheme:
```C++
struct Foo : public ObservableBase {
    using ObservationTicket = ObservableBase::ObservationTicket;
    enum : uint64_t {
        EventA = 0x0001,
        EventB = 0x0002,
    };

    ObservationTicket ObserveEventA( function<void()> _callback ) {
      return AddObserver( move(_callback), EventA ); }
    ObservationTicket ObserveEventB( function<void()> _callback ) {
      return AddObserver( move(_callback), EventB ); }

    void Bar() {
      // do something useful
      FireObservers( EventA );
      // do something even more useful
      FireObservers( EventA | EventB );
    }
};
// client side:
auto observation_ticket = m_FooInstance.ObserveEventA( []{
  cout << "Foo made something useful!" << endl; } );
```

Habanero/SerialQueue.h
-----------
High-level wrapper abstraction on top of GCD's dispatch_async() serial execution queue with following additions:
  * Callback signals about queue's load state.
  * IsStopped() concept, lets you to flag running tasks as being discarded. The IsStopped() flag is automatically cleared with queue becomes empty.
  * Queue's length probing.
  * Compatible with C++ lambdas and function<>'s.
```C++
SerialQueue sq;
sq.SetOnDry( []{ cout << "ready for orders!"; } );
sq.Run([&]{
  if( sq.IsStopped() )
    return;
  /* calculate trajectories */
});
sq.Run([&]{
  if( sq.IsStopped() )
    return;
  /* launch missiles */
});
if( rand() % 2 == 0 )
  sq.Stop();
sq.Wait();
```

Habanero/spinlock.h
-----------
Spinlock implementation based on C++11 atomics, conforming BasicLockable concept. When thread can't acquire the lock, it will lower own priority via Mach's swtch_pri() syscall. Also provides useful LOCK_GUARD(lock_object){...} macro and call_locked(lock_object, [=]{....}) template function:
```C++
spinlock data_lock;
// ...
LOCK_GUARD(data_lock) {
  // concurrently access data
}
```

Habanero/tiny_string.h
-----------
tiny_string is a std::string implementation with a small sizeof - 8 bytes. It assumes the following:
  * platform with 64-bit pointers (for my case it is x86-64)
  * little endian
  * only char as a value type, not a template class
  * no allocators
  * nearly C++14 compatible

The reason why this class exists is a situation when you need to store a string in an object and most of the times it will be empty. With this case basically there are two options:
  * use straightforward std::string, which is 24 bytes long for example on clang's std::string implemetation. Wasting a lot of memory for nothing.
  * use C-style char* buffer - 8 bytes for pointer. Manually allocate and deallocate it, deal with copying/moving etc. Boring and error-prone.

So tiny_string can be used - for strings up to 6 characters it will use a built-in buffer and will use malloc/realloc for larger strings.

Habanero/variable_container.h
-----------
Tempate container, which underlying structure is defined in run-time. Container access is based on integer index. Container can take form of 3 states: a single value - T, a sparse set of T objects - unordered_map<T>, or a dense set of T objects - vector<T>. Interface differs a bit from generic STL containers:
  * mode() tells in which state this container is.
  * reset() changes the container state.
  * has() method to probe is there's an object at some index.
  * is_contiguous()/compress_contiguous() lets compress sparse type into dense type. 


