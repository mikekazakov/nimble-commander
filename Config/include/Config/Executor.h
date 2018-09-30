#pragma once

#include <chrono>
#include <functional>

namespace nc::config {

class Executor 
{
public:
    virtual ~Executor() = default;
    virtual void Execute( std::function<void()> _block ) = 0;        
};

class ImmediateExecutor : public Executor
{
public:
    void Execute( std::function<void()> _block ) override;
};

class DelayedAsyncExecutor : public Executor
{
public:
    DelayedAsyncExecutor(std::chrono::nanoseconds _delay);
    void Execute( std::function<void()> _block ) override;
private:
    std::chrono::nanoseconds m_Delay;
};
    
}
