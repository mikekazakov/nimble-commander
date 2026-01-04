// Copyright (C) 2016-2026 Michael Kazakov. Subject to GNU General Public License version 3.
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
 */
class ObservableBase
{
public:
    struct ObservationTicket;

    ObservableBase();
    ObservableBase(const ObservableBase &) = delete;
    ~ObservableBase();

    ObservableBase &operator=(const ObservableBase &) = delete;

protected:
    ObservationTicket AddObserver(std::function<void()> _callback,
                                  uint64_t _mask = std::numeric_limits<uint64_t>::max());
    void FireObservers(uint64_t _mask = std::numeric_limits<uint64_t>::max()) const;

private:
    void StopObservation(uint64_t _ticket);

    struct Observer {
        std::function<void()> callback;
        uint64_t ticket;
        uint64_t mask;
    };

    std::shared_ptr<std::vector<std::shared_ptr<Observer>>> m_Observers;
    mutable nc::spinlock m_ObserversLock;
    std::atomic_ullong m_ObservationTicket{1};
};

struct ObservableBase::ObservationTicket {
    ObservationTicket() noexcept;
    ObservationTicket(const ObservationTicket &) = delete;
    ObservationTicket(ObservationTicket && /*_r*/) noexcept;
    ~ObservationTicket();

    void operator=(const ObservationTicket &) = delete;
    ObservationTicket &operator=(ObservationTicket && /*_r*/) noexcept;

    operator bool() const noexcept;

private:
    ObservationTicket(ObservableBase *_inst, unsigned long _ticket) noexcept;

    ObservableBase *instance;
    uint64_t ticket;
    friend class ObservableBase;
};

} // namespace nc::base
