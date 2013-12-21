//
//  DispatchQueue.h
//  Files
//
//  Created by Michael G. Kazakov on 20.12.13.
//  Copyright (c) 2013 Michael G. Kazakov. All rights reserved.
//

#include <memory>
#include <atomic>

using namespace std;

class SerialQueueT : public enable_shared_from_this<SerialQueueT>
{
public:
    SerialQueueT(const char *_label = NULL);
    ~SerialQueueT();
    
    // operations
    
    /**
     * Just a form to call the long Run(..) version with dummy parameter
     */
    void Run( void (^_block)() );
    
    /**
     * Run will not start any task if IsStopped() is true.
     */
    void Run( void (^_block)(shared_ptr<SerialQueueT> _que) );
    
    /**
     * Raised IsStopped() flag so currently running task can caught it.
     * Will skip any enqueued tasks and not add any more until became dry, then will automaticaly lower this flag
     */
    void Stop();
    
    /**
     * Synchronously wait until queue became dry. Note that OnDry() will be called before Wait() will return
     */
    void Wait();
    
    // current state
    bool IsStopped() const;
    int Length() const;
    bool Empty() const;
    
    // handlers
    void OnDry( void (^_block)() );
    void OnWet( void (^_block)() );
    void OnChange( void (^_block)() );
    
private:
    SerialQueueT(const SerialQueueT&) = delete;
    void operator=(const SerialQueueT&) = delete;
    void BecameDry();
    void BecameWet();
    void Changed();
    dispatch_queue_t m_Queue;
    atomic<int>      m_Length;
    atomic_bool      m_Stopped;
    void           (^m_OnDry)();
    void           (^m_OnWet)();
    void           (^m_OnChange)();
};

typedef shared_ptr<SerialQueueT> SerialQueue;

class DispatchGroup
{
public:
    enum Priority
    {
        High        = DISPATCH_QUEUE_PRIORITY_HIGH,
        Default     = DISPATCH_QUEUE_PRIORITY_DEFAULT,
        Low         = DISPATCH_QUEUE_PRIORITY_LOW,
        Background  = DISPATCH_QUEUE_PRIORITY_BACKGROUND
    };
    
    DispatchGroup(Priority _priority = Default);
    ~DispatchGroup();
    
    /**
     * Run _block in group on queue with prioriry specified at construction time
     */
    void Run( void (^_block)() );
    
    /**
     * Wait indefinitely until all task in group will be finished
     */
    void Wait();
    
private:
    DispatchGroup(const DispatchGroup&) = delete;
    void operator=(const DispatchGroup&) = delete;
    dispatch_queue_t m_Queue;
    dispatch_group_t m_Group;
};


