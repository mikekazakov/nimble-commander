/* Copyright (c) 2017-2023 Michael G. Kazakov
 * Permission is hereby granted, free of charge, to any person obtaining a copy of this software
 * and associated documentation files (the "Software"), to deal in the Software without restriction,
 * including without limitation the rights to use, copy, modify, merge, publish, distribute,
 * sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is
 * furnished to do so, subject to the following conditions:
 * The above copyright notice and this permission notice shall be included in all copies or
 * substantial portions of the Software.
 * THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING
 * BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND
 * NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM,
 * DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
 * OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE. */
#pragma once

#include <functional>
#include <memory>
#include <vector>
#include <atomic>
#include "spinlock.h"

namespace nc::base {

/**
 * Fully thread-safe and intended for concurrent usage.
 * Observers may be triggered from any thread, synchronously.
 * Should be reentrant in any meaning.
 * Observable object can have a a limited life-time scope.
 */
class ScopedObservableBase
{
public:
    ScopedObservableBase();
    ~ScopedObservableBase();
    struct ObservationTicket;

protected:
    ObservationTicket AddTicketedObserver(std::function<void()> _callback,
                                          uint64_t _mask = std::numeric_limits<uint64_t>::max());
    void AddUnticketedObserver(std::function<void()> _callback, uint64_t _mask = std::numeric_limits<uint64_t>::max());
    void FireObservers(uint64_t _mask = std::numeric_limits<uint64_t>::max()) const;

private:
    ScopedObservableBase(ScopedObservableBase &) = delete;
    void operator=(ScopedObservableBase &) = delete;
    void StopObservation(uint64_t _ticket);

    struct Indirect {
        ScopedObservableBase *instance;
        nc::spinlock lock;
    };

    struct Observer {
        std::function<void()> callback;
        uint64_t ticket;
        uint64_t mask;
    };

    std::shared_ptr<std::vector<std::shared_ptr<Observer>>> m_Observers;
    mutable nc::spinlock m_ObserversLock;
    std::atomic_ullong m_ObservationTicket{1};
    std::shared_ptr<Indirect> m_Indirect;

    friend struct ObservationTicket;
};

struct ScopedObservableBase::ObservationTicket {
    ObservationTicket() noexcept;
    ObservationTicket(ObservationTicket &&) noexcept;
    ~ObservationTicket();
    const ObservationTicket &operator=(ObservationTicket &&) noexcept;
    operator bool() const noexcept;

private:
    ObservationTicket(std::shared_ptr<ScopedObservableBase::Indirect> _inst, unsigned long _ticket) noexcept;
    ObservationTicket(const ObservationTicket &) = delete;
    void operator=(const ObservationTicket &) = delete;

    std::shared_ptr<ScopedObservableBase::Indirect> indirect;
    uint64_t ticket;
    friend class ScopedObservableBase;
};

} // namespace nc::base
