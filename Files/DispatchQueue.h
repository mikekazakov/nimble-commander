//
//  DispatchQueue.h
//  Files
//
//  Created by Michael G. Kazakov on 20.12.13.
//  Copyright (c) 2013 Michael G. Kazakov. All rights reserved.
//

#pragma once

class SerialQueueT : public enable_shared_from_this<SerialQueueT>
{
public:
    SerialQueueT(const char *_label = NULL);
    ~SerialQueueT();
    
    /**
     * Just a form to call the long Run(..) version with dummy parameter
     */
    void Run( function<void()> _block );
    
    /**
     * Starts _block asynchronously in this queue.
     * Run will not start any task if IsStopped() is true.
     */
    void Run( function<void(const shared_ptr<SerialQueueT> &_que)> _block );
    
    /**
     * Run block synchronous against queue.
     * Will not run block if currently IsStopped() is true.
     * Will not call OnDry/OnWet/OnChange and will not change queue's- length.
     */
    void RunSync( function<void(const shared_ptr<SerialQueueT> &_que)> _block );

    /**
     * Run block synchronous againt current queue, just for client's convenience.
     * Will not run block if currently IsStopped() is true.
     * Will not call OnDry/OnWet/OnChange and will not change queue's- length.
     */
    void RunSyncHere( function<void(const shared_ptr<SerialQueueT> &_que)> _block );
    
    /**
     * Raised IsStopped() flag so currently running task can caught it.
     * Will skip any enqueued tasks and not add any more until became dry, then will automaticaly lower this flag
     */
    void Stop();
    
    /**
     * Synchronously wait until queue became dry. Note that OnDry() will be called before Wait() will return
     */
    void Wait();
    
    /**
     * Return value of a stop flag.
     */
    bool IsStopped() const;
    
    /**
     * Returns count of block commited into queue, including current running block, if any.
     * Zero returned length means that queue is dry.
     */
    int Length() const;
    
    /**
     * Actually returns Length() == 0. Just a syntax sugar.
     */
    bool Empty() const;
    
    /**
     * Sets handler to be called when queue becomes dry (no blocks are commited or running).
     */
    void OnDry( function<void()> _on_dry );
    
    /**
     * Sets handler to be called when queue becomes wet (when block is commited to run in it).
     */
    void OnWet( function<void()> _on_wet );
    
    /**
     * Sets handler to be called when queue length is changed.
     */
    void OnChange( function<void()> _on_change );
    
    /**
     * Actually make_shared<SerialQueueT>().
     */
    inline static shared_ptr<SerialQueueT> Make(const char *_label = NULL) { return make_shared<SerialQueueT>(_label); };
    
private:
    SerialQueueT(const SerialQueueT&) = delete;
    void operator=(const SerialQueueT&) = delete;
    void BecameDry();
    void BecameWet();
    void Changed();
    dispatch_queue   m_Queue;
    atomic_int       m_Length = {0};
    atomic_bool      m_Stopped = {false};
    
    mutex            m_SignalsGuard;
    function<void()> m_OnDry;
    function<void()> m_OnWet;
    function<void()> m_OnChange;
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
    void Run( function<void()> _f ) const;
    
    /**
     * Wait indefinitely until all task in group will be finished
     */
    void Wait();
    
    /**
     * Returnes amount of blocks currently running in this group.
     */
    unsigned Count() const;
    
private:
    DispatchGroup(const DispatchGroup&) = delete;
    void operator=(const DispatchGroup&) = delete;
    dispatch_queue_t m_Queue;
    dispatch_group_t m_Group;
    mutable atomic_uint m_Count{0};
};


