// Copyright (C) 2018 Michael Kazakov. Subject to GNU General Public License version 3.
#include <VFSIcon/IconRepositoryImpl.h>
#include <Habanero/dispatch_cpp.h>

namespace nc::vfsicon::detail {

using Base = IconRepositoryImplBase; 
    
const std::shared_ptr<Base::Executor>
    Base::MainQueueExecutor::instance{ std::make_shared<Base::MainQueueExecutor>() };
        
void Base::MainQueueExecutor::Execute( std::function<void()> _block )
{   
    dispatch_to_main_queue( std::move(_block) );
}

Base::GCDLimitedConcurrentQueue::GCDLimitedConcurrentQueue( short _concurrency_limit ):
    m_Concurrency( _concurrency_limit )    
{
    static_assert( sizeof(*this) == 80 );    
    if( _concurrency_limit < 1 ) {
        auto msg = "GCDLimitedConcurrentQueue: _concurrency_limit can't be less than 1";
        throw std::logic_error(msg);
    }
    m_Group = dispatch_group_create();
    m_Queue = dispatch_get_global_queue(QOS_CLASS_DEFAULT, 0);
}
    
Base::GCDLimitedConcurrentQueue::~GCDLimitedConcurrentQueue()
{
    dispatch_group_wait(m_Group, DISPATCH_TIME_FOREVER);
}

void Base::GCDLimitedConcurrentQueue::Execute( std::function<void()> _block )
{
    if( _block == nullptr )
        return;
    
    auto lock = std::lock_guard{m_AwaitingLock};
    
    if( m_Scheduled < m_Concurrency ) {
        m_Scheduled++;
        DispatchForAsynExecution( std::move(_block) );
    }
    else {
        m_Awaiting.emplace( std::move(_block) );
    }
}

int Base::GCDLimitedConcurrentQueue::QueueLength() const
{
    auto lock = std::lock_guard{m_AwaitingLock};    
    return (int)m_Awaiting.size();
}

void Base::GCDLimitedConcurrentQueue::RunBlock( const std::function<void()> &_client_block )
{
    try {
        _client_block();
    }
    catch (...) {
        std::cerr << "Exception caught inside GCDLimitedConcurrentQueue" << std::endl; 
    }
    
    auto lock = std::lock_guard{m_AwaitingLock};
    
    if( m_Awaiting.empty() == false ) {
        auto new_client_block = std::move(m_Awaiting.front());
        m_Awaiting.pop();        
        DispatchForAsynExecution( std::move(new_client_block) );
    }
    else {
        m_Scheduled--;
    }
}

void Base::GCDLimitedConcurrentQueue::DispatchForAsynExecution( std::function<void()> _client_block)
{
    auto block = [this, client_block=std::move(_client_block)] {
        RunBlock(client_block);
    };
    dispatch_group_async(m_Group, m_Queue, std::move(block));
}
    
}
