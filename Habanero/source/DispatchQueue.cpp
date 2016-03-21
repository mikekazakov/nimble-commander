//
//  DispatchQueue.mm
//  Files
//
//  Created by Michael G. Kazakov on 20.12.13.
//  Copyright (c) 2013 Michael G. Kazakov. All rights reserved.
//

#include <Habanero/DispatchQueue.h>

using namespace std;

////////////////////////////////////////////////////////////////////////////////
// SerialQueueT implementation
////////////////////////////////////////////////////////////////////////////////
std::shared_ptr<SerialQueueT> SerialQueueT::Make(const char *_label)
{
    return std::make_shared<SerialQueueT>(_label);
};

std::shared_ptr<SerialQueueT> SerialQueueT::Make(const std::string &_label)
{
    return Make(_label.c_str());
};

SerialQueueT::SerialQueueT(const char *_label):
    m_Queue(_label)
{
}

SerialQueueT::~SerialQueueT()
{
    Stop();
    Wait();
}

void SerialQueueT::OnDry( function<void()> _on_dry )
{
    lock_guard<mutex> lock(m_SignalsGuard);
    m_OnDry = _on_dry;
}

void SerialQueueT::OnWet( function<void()> _on_wet )
{
    lock_guard<mutex> lock(m_SignalsGuard);
    m_OnWet = _on_wet;
}

void SerialQueueT::OnChange( function<void()> _on_change )
{
    lock_guard<mutex> lock(m_SignalsGuard);
    m_OnChange = _on_change;
}

void SerialQueueT::Stop()
{
    if(m_Length > 0)
        m_Stopped = true;
}

bool SerialQueueT::IsStopped() const
{
    return m_Stopped;
}

void SerialQueueT::Run( function<void()> _block )
{
    Run( [_block = move(_block)](const shared_ptr<SerialQueueT> &_unused) { _block(); } );
}

void SerialQueueT::Run( function<void(const shared_ptr<SerialQueueT> &_que)> _block )
{
    if(m_Stopped) // won't push any the tasks until we're stopped
        return;
    
    if((++m_Length) == 1)
        BecameWet();
    Changed();
    
    __block auto block = move(_block);
    __block auto me = shared_from_this();
    
    m_Queue.async(^{
        
        if(me->m_Stopped == false)
            block(me);
        
        if(--(me->m_Length) == 0)
            BecameDry();
        Changed();
    });
}

void SerialQueueT::RunSync( function<void(const shared_ptr<SerialQueueT> &_que)> _block )
{
    if(m_Stopped) // won't push any the tasks until we're stopped
        return;
    
    __block auto block = move(_block);
    __block auto me = shared_from_this();
    
    m_Queue.sync(^{
        block(me);
    });
}

void SerialQueueT::RunSyncHere( function<void(const shared_ptr<SerialQueueT> &_que)> _block )
{
    if(m_Stopped) // won't push any the tasks until we're stopped
        return;
    _block(shared_from_this());
}

void SerialQueueT::Wait()
{
    if(m_Length == 0)
        return;
    
    m_Queue.sync(^{});
}

int SerialQueueT::Length() const noexcept
{
    return m_Length;
}

bool SerialQueueT::Empty() const noexcept
{
    return m_Length == 0;
}

void SerialQueueT::BecameDry()
{
    m_Stopped = false;

    lock_guard<mutex> lock(m_SignalsGuard);
    if(m_OnDry)
        m_OnDry();
}

void SerialQueueT::BecameWet()
{
    lock_guard<mutex> lock(m_SignalsGuard);
    if(m_OnWet)
        m_OnWet();
}

void SerialQueueT::Changed()
{
    lock_guard<mutex> lock(m_SignalsGuard);
    if(m_OnChange)
        m_OnChange();
}
