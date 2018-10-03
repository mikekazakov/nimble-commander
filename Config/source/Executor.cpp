// Copyright (C) 2018 Michael Kazakov. Subject to GNU General Public License version 3.
#include "Executor.h"
#include <Habanero/dispatch_cpp.h>

namespace nc::config {

void ImmediateExecutor::Execute( std::function<void()> _block )
{
    assert( _block );
    _block();
}
    
DelayedAsyncExecutor::DelayedAsyncExecutor(std::chrono::nanoseconds _delay):
    m_Delay(_delay)
{   
    assert( _delay.count() >= 0 );
}
    
void DelayedAsyncExecutor::Execute( std::function<void()> _block )
{
    assert( _block );
    dispatch_to_background_after(m_Delay, std::move(_block) );
}

}
