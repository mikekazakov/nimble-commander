//
//  DispatchQueue.mm
//  Files
//
//  Created by Michael G. Kazakov on 20.12.13.
//  Copyright (c) 2013 Michael G. Kazakov. All rights reserved.
//

#include "DispatchQueue.h"

////////////////////////////////////////////////////////////////////////////////
// SerialQueueT implementation
////////////////////////////////////////////////////////////////////////////////
SerialQueueT::SerialQueueT(const char *_label):
    m_Queue(dispatch_queue_create(_label, DISPATCH_QUEUE_SERIAL)),
    m_Length(0),
    m_Stopped(false)
{
    assert(m_Queue != 0);
}

SerialQueueT::~SerialQueueT()
{
    assert(Length() == 0);
    dispatch_release(m_Queue);
}

void SerialQueueT::OnDry( void (^_block)() )
{
    m_OnDry = _block;
}

void SerialQueueT::OnWet( void (^_block)() )
{
    m_OnWet = _block;
}

void SerialQueueT::OnChange( void (^_block)() )
{
    m_OnChange = _block;
}

void SerialQueueT::Stop()
{
    if(m_Length.load() > 0)
        m_Stopped.store(true);
}

bool SerialQueueT::IsStopped() const
{
    return m_Stopped.load();
}

void SerialQueueT::Run( void (^_block)() )
{
    Run( ^(shared_ptr<SerialQueueT> _unused) { _block(); } );
}

void SerialQueueT::Run( void (^_block)(shared_ptr<SerialQueueT>) )
{
    if(m_Stopped.load()) // won't push any the tasks until we're stopped
        return;
    
    if((++m_Length) == 1)
        BecameWet();
    Changed();
    
    auto me = shared_from_this();
    
    dispatch_async(m_Queue, ^{
        
        if(me->m_Stopped.load() == false)
            _block(me);
        
        if(--(me->m_Length) == 0)
            BecameDry();
        Changed();
    });
}

void SerialQueueT::RunSync(void (^_block)(shared_ptr<SerialQueueT> _que))
{
    if(m_Stopped.load()) // won't push any the tasks until we're stopped
        return;
    
    auto me = shared_from_this();
    
    dispatch_sync(m_Queue, ^{
        _block(me);
    });
}

void SerialQueueT::RunSyncHere(void (^_block)(shared_ptr<SerialQueueT> _que))
{
    if(m_Stopped.load()) // won't push any the tasks until we're stopped
        return;
    _block(shared_from_this());
}

void SerialQueueT::Wait()
{
    if(m_Length.load() == 0)
        return;
    
    dispatch_sync(m_Queue, ^{});
}

int SerialQueueT::Length() const
{
    return m_Length.load();
}

bool SerialQueueT::Empty() const
{
    return m_Length.load() == 0;
}

void SerialQueueT::BecameDry()
{
    m_Stopped.store(false);
    
    if(m_OnDry != 0)
        m_OnDry();
}

void SerialQueueT::BecameWet()
{
    if(m_OnWet != 0)
        m_OnWet();
}

void SerialQueueT::Changed()
{
    if(m_OnChange != 0)
        m_OnChange();
}

////////////////////////////////////////////////////////////////////////////////
// DispatchGroup implementation
////////////////////////////////////////////////////////////////////////////////
DispatchGroup::DispatchGroup(Priority _priority):
    m_Queue(dispatch_get_global_queue(_priority, 0)),
    m_Group(dispatch_group_create())
{
    assert(m_Queue != 0);
    assert(m_Group != 0);
}

DispatchGroup::~DispatchGroup()
{
    dispatch_release(m_Group);
}

void DispatchGroup::Run( void (^_block)() )
{
    dispatch_group_async(m_Group, m_Queue, ^{
        m_Count++;
        _block();
        m_Count--;
    });
}

void DispatchGroup::Wait()
{
    dispatch_group_wait(m_Group, DISPATCH_TIME_FOREVER);
}

unsigned DispatchGroup::Count() const
{
    return m_Count;
}
