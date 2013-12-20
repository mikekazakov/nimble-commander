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

class SerialQueue : public enable_shared_from_this<SerialQueue>
{
public:
    SerialQueue(const char *_label = NULL);
    ~SerialQueue();
    
    void Run( void (^_block)() );
    void Run( void (^_block)(shared_ptr<SerialQueue> _que) );
    
    int Length() const;
    
private:
    SerialQueue(const SerialQueue&) = delete;
    void operator=(const SerialQueue&) = delete;
    dispatch_queue_t m_Queue;
    atomic<int>      m_Length;
};
