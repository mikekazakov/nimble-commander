//
//  DispatchQueue.mm
//  Files
//
//  Created by Michael G. Kazakov on 20.12.13.
//  Copyright (c) 2013 Michael G. Kazakov. All rights reserved.
//

#include "DispatchQueue.h"

SerialQueue::SerialQueue(const char *_label):
    m_Queue(dispatch_queue_create(_label, DISPATCH_QUEUE_SERIAL)),
    m_Length(0)
{
    assert(m_Queue != 0);
}

SerialQueue::~SerialQueue()
{
    assert(Length() == 0);
    dispatch_release(m_Queue);
}

void SerialQueue::Run( void (^_block)() )
{
    Run( ^(shared_ptr<SerialQueue> _unused) {
        
            _block();
        
        }
    );
}

void SerialQueue::Run( void (^_block)(shared_ptr<SerialQueue>) )
{
    ++m_Length;
    
    auto me = shared_from_this();
    
    dispatch_async(m_Queue, ^{
        
        _block(me);
        
        --(me->m_Length);
        
    });
}

int SerialQueue::Length() const
{
    return m_Length.load();
}
