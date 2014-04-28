// Copyright Howard Hinnant 2007-2010. Distributed under the Boost
// Software License, Version 1.0. (see http://www.boost.org/LICENSE_1_0.txt)

#include "shared_mutex"
#include <thread>

namespace ting
{

// shared_mutex

shared_mutex::shared_mutex()
    : state_(0)
{
}

shared_mutex::~shared_mutex()
{
    std::lock_guard<mutex_t> _(mut_);
}

// Exclusive ownership

void
shared_mutex::lock()
{
    std::unique_lock<mutex_t> lk(mut_);
    while (state_ & write_entered_)
        gate1_.wait(lk);
    state_ |= write_entered_;
    while (state_ & n_readers_)
        gate2_.wait(lk);
}

bool
shared_mutex::try_lock()
{
    std::unique_lock<mutex_t> lk(mut_);
    if (state_ == 0)
    {
        state_ = write_entered_;
        return true;
    }
    return false;
}

void
shared_mutex::unlock()
{
    std::lock_guard<mutex_t> _(mut_);
    state_ = 0;
    gate1_.notify_all();
}

// Shared ownership

void
shared_mutex::lock_shared()
{
    std::unique_lock<mutex_t> lk(mut_);
    while ((state_ & write_entered_) || (state_ & n_readers_) == n_readers_)
        gate1_.wait(lk);
    count_t num_readers = (state_ & n_readers_) + 1;
    state_ &= ~n_readers_;
    state_ |= num_readers;
}

bool
shared_mutex::try_lock_shared()
{
    std::unique_lock<mutex_t> lk(mut_);
    count_t num_readers = state_ & n_readers_;
    if (!(state_ & write_entered_) && num_readers != n_readers_)
    {
        ++num_readers;
        state_ &= ~n_readers_;
        state_ |= num_readers;
        return true;
    }
    return false;
}

void
shared_mutex::unlock_shared()
{
    std::lock_guard<mutex_t> _(mut_);
    count_t num_readers = (state_ & n_readers_) - 1;
    state_ &= ~n_readers_;
    state_ |= num_readers;
    if (state_ & write_entered_)
    {
        if (num_readers == 0)
            gate2_.notify_one();
    }
    else
    {
        if (num_readers == n_readers_ - 1)
            gate1_.notify_one();
    }
}

// upgrade_mutex

upgrade_mutex::upgrade_mutex()
    : gate1_(),
      gate2_(),
      state_(0)
{
}

upgrade_mutex::~upgrade_mutex()
{
    std::lock_guard<mutex_t> _(mut_);
}

// Exclusive ownership

void
upgrade_mutex::lock()
{
    std::unique_lock<mutex_t> lk(mut_);
    while (state_ & (write_entered_ | upgradable_entered_))
        gate1_.wait(lk);
    state_ |= write_entered_;
    while (state_ & n_readers_)
        gate2_.wait(lk);
}

bool
upgrade_mutex::try_lock()
{
    std::unique_lock<mutex_t> lk(mut_);
    if (state_ == 0)
    {
        state_ = write_entered_;
        return true;
    }
    return false;
}

void
upgrade_mutex::unlock()
{
    std::lock_guard<mutex_t> _(mut_);
    state_ = 0;
    gate1_.notify_all();
}

// Shared ownership

void
upgrade_mutex::lock_shared()
{
    std::unique_lock<mutex_t> lk(mut_);
    while ((state_ & write_entered_) || (state_ & n_readers_) == n_readers_)
        gate1_.wait(lk);
    count_t num_readers = (state_ & n_readers_) + 1;
    state_ &= ~n_readers_;
    state_ |= num_readers;
}

bool
upgrade_mutex::try_lock_shared()
{
    std::unique_lock<mutex_t> lk(mut_);
    count_t num_readers = state_ & n_readers_;
    if (!(state_ & write_entered_) && num_readers != n_readers_)
    {
        ++num_readers;
        state_ &= ~n_readers_;
        state_ |= num_readers;
        return true;
    }
    return false;
}

void
upgrade_mutex::unlock_shared()
{
    std::lock_guard<mutex_t> _(mut_);
    count_t num_readers = (state_ & n_readers_) - 1;
    state_ &= ~n_readers_;
    state_ |= num_readers;
    if (state_ & write_entered_)
    {
        if (num_readers == 0)
            gate2_.notify_one();
    }
    else
    {
        if (num_readers == n_readers_ - 1)
            gate1_.notify_one();
    }
}

// Upgrade ownership

void
upgrade_mutex::lock_upgrade()
{
    std::unique_lock<mutex_t> lk(mut_);
    while ((state_ & (write_entered_ | upgradable_entered_)) || 
           (state_ & n_readers_) == n_readers_)
        gate1_.wait(lk);
    count_t num_readers = (state_ & n_readers_) + 1;
    state_ &= ~n_readers_;
    state_ |= upgradable_entered_ | num_readers;
}

bool
upgrade_mutex::try_lock_upgrade()
{
    std::unique_lock<mutex_t> lk(mut_);
    count_t num_readers = state_ & n_readers_;
    if (!(state_ & (write_entered_ | upgradable_entered_))
        && num_readers != n_readers_)
    {
        ++num_readers;
        state_ &= ~n_readers_;
        state_ |= upgradable_entered_ | num_readers;
        return true;
    }
    return false;
}

void
upgrade_mutex::unlock_upgrade()
{
    {
        std::lock_guard<mutex_t> _(mut_);
        count_t num_readers = (state_ & n_readers_) - 1;
        state_ &= ~(upgradable_entered_ | n_readers_);
        state_ |= num_readers;
    }
    gate1_.notify_all();
}

// Shared <-> Exclusive

bool
upgrade_mutex::try_unlock_shared_and_lock()
{
    std::unique_lock<mutex_t> lk(mut_);
    if (state_ == 1)
    {
        state_ = write_entered_;
        return true;
    }
    return false;
}

void
upgrade_mutex::unlock_and_lock_shared()
{
    {
        std::lock_guard<mutex_t> _(mut_);
        state_ = 1;
    }
    gate1_.notify_all();
}

// Shared <-> Upgrade

bool
upgrade_mutex::try_unlock_shared_and_lock_upgrade()
{
    std::unique_lock<mutex_t> lk(mut_);
    if (!(state_ & (write_entered_ | upgradable_entered_)))
    {
        state_ |= upgradable_entered_;
        return true;
    }
    return false;
}

void
upgrade_mutex::unlock_upgrade_and_lock_shared()
{
    {
        std::lock_guard<mutex_t> _(mut_);
        state_ &= ~upgradable_entered_;
    }
    gate1_.notify_all();
}

// Upgrade <-> Exclusive

void
upgrade_mutex::unlock_upgrade_and_lock()
{
    std::unique_lock<mutex_t> lk(mut_);
    count_t num_readers = (state_ & n_readers_) - 1;
    state_ &= ~(upgradable_entered_ | n_readers_);
    state_ |= write_entered_ | num_readers;
    while (state_ & n_readers_)
        gate2_.wait(lk);
}

bool
upgrade_mutex::try_unlock_upgrade_and_lock()
{
    std::unique_lock<mutex_t> lk(mut_);
    if (state_ == (upgradable_entered_ | 1))
    {
        state_ = write_entered_;
        return true;
    }
    return false;
}

void
upgrade_mutex::unlock_and_lock_upgrade()
{
    {
        std::lock_guard<mutex_t> _(mut_);
        state_ = upgradable_entered_ | 1;
    }
    gate1_.notify_all();
}

}  // ting
