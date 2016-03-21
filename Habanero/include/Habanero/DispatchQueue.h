//
//  DispatchQueue.h
//  Files
//
//  Created by Michael G. Kazakov on 20.12.13.
//  Copyright (c) 2013 Michael G. Kazakov. All rights reserved.
//

#pragma once

#include <memory>
#include <functional>
#include <mutex>

#include "dispatch_cpp.h"

class SerialQueueT : public std::enable_shared_from_this<SerialQueueT>
{
public:
    SerialQueueT(const char *_label = NULL);
    ~SerialQueueT();
    
    /**
     * Just a form to call the long Run(..) version with dummy parameter
     */
    void Run( std::function<void()> _block );
    
    /**
     * Starts _block asynchronously in this queue.
     * Run will not start any task if IsStopped() is true.
     */
    void Run( std::function<void(const std::shared_ptr<SerialQueueT> &_que)> _block );
    
    /**
     * Run block synchronous against queue.
     * Will not run block if currently IsStopped() is true.
     * Will not call OnDry/OnWet/OnChange and will not change queue's- length.
     */
    void RunSync( std::function<void(const std::shared_ptr<SerialQueueT> &_que)> _block );

    /**
     * Run block synchronous againt current queue, just for client's convenience.
     * Will not run block if currently IsStopped() is true.
     * Will not call OnDry/OnWet/OnChange and will not change queue's- length.
     */
    void RunSyncHere( std::function<void(const std::shared_ptr<SerialQueueT> &_que)> _block );
    
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
    int Length() const noexcept;
    
    /**
     * Actually returns Length() == 0. Just a syntax sugar.
     */
    bool Empty() const noexcept;
    
    /**
     * Sets handler to be called when queue becomes dry (no blocks are commited or running).
     */
    void OnDry( std::function<void()> _on_dry );
    
    /**
     * Sets handler to be called when queue becomes wet (when block is commited to run in it).
     */
    void OnWet( std::function<void()> _on_wet );
    
    /**
     * Sets handler to be called when queue length is changed.
     */
    void OnChange( std::function<void()> _on_change );
    
    /**
     * Actually make_shared<SerialQueueT>().
     */
    static std::shared_ptr<SerialQueueT> Make(const char *_label = NULL);
    static std::shared_ptr<SerialQueueT> Make(const std::string &_label);
    
private:
    SerialQueueT(const SerialQueueT&) = delete;
    void operator=(const SerialQueueT&) = delete;
    void BecameDry();
    void BecameWet();
    void Changed();
    dispatch_queue   m_Queue;
    std::atomic_int       m_Length = {0};
    std::atomic_bool      m_Stopped = {false};
    
    std::mutex            m_SignalsGuard;
    std::function<void()> m_OnDry;
    std::function<void()> m_OnWet;
    std::function<void()> m_OnChange;
};

typedef std::shared_ptr<SerialQueueT> SerialQueue;

