#include <VFSIcon/IconRepositoryImpl.h>
#include <Habanero/dispatch_cpp.h>

namespace nc::vfsicon::detail {

using Base = IconRepositoryImplBase; 
    
const std::shared_ptr<Base::Executor>
    Base::MainQueueExecutor::instance{ std::make_shared<Base::MainQueueExecutor>() };
//static const std::shared_ptr<Executor> instance;
        
void Base::MainQueueExecutor::Execute( std::function<void()> _block )
{   
    dispatch_to_main_queue( std::move(_block) );
}

Base::GCDLimitedConcurrentQueue::GCDLimitedConcurrentQueue( int _concurrency_limit ):
    m_Concurrency(_concurrency_limit)    
{
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
    auto lock = std::lock_guard{m_AwaitingLock};
    
    if( m_Scheduled < m_Concurrency ) {
        m_Scheduled++;
        
        auto block = [this, client_block=std::move(_block)]{
            Block(client_block);
        };
        
        dispatch_group_async(m_Group, m_Queue, std::move(block));
    }
    else {
        m_Awaiting.emplace(std::move(_block));
    }
}

int Base::GCDLimitedConcurrentQueue::Length() const
{
    auto lock = std::lock_guard{m_AwaitingLock};    
    return (int)m_Awaiting.size();
}

void Base::GCDLimitedConcurrentQueue::Block( const std::function<void()> &_client_block )
{
    _client_block();
    
    auto lock = std::lock_guard{m_AwaitingLock};
    if( m_Awaiting.empty() == false ) {
        auto new_client_block = std::move(m_Awaiting.front());
        m_Awaiting.pop();
        
        auto block = [this, client_block=std::move(new_client_block)]{
            Block(client_block);
        };
        dispatch_group_async(m_Group, m_Queue, std::move(block));        
    }
    else {
        m_Scheduled--;
    }
}
    
}
