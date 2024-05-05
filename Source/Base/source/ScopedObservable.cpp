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
#include <Base/algo.h>
#include <Base/ScopedObservable.h>

namespace nc::base {

ScopedObservableBase::ObservationTicket::ObservationTicket() noexcept : indirect(nullptr), ticket(0)
{
}

ScopedObservableBase::ObservationTicket::ObservationTicket(std::shared_ptr<ScopedObservableBase::Indirect> _inst,
                                                           unsigned long _ticket) noexcept
    : indirect(std::move(_inst)), ticket(_ticket)
{
}

ScopedObservableBase::ObservationTicket::ObservationTicket(ObservationTicket &&_r) noexcept
    : indirect(std::move(_r.indirect)), ticket(_r.ticket)
{
    _r.ticket = 0;
}

ScopedObservableBase::ObservationTicket::~ObservationTicket()
{
    if( *this ) {
        const auto lock = std::lock_guard{indirect->lock};
        if( indirect->instance )
            indirect->instance->StopObservation(ticket);
    }
}

const ScopedObservableBase::ObservationTicket &
ScopedObservableBase::ObservationTicket::operator=(ScopedObservableBase::ObservationTicket &&_r)
{
    if( *this ) {
        const auto lock = std::lock_guard{indirect->lock};
        if( indirect->instance )
            indirect->instance->StopObservation(ticket);
    }
    indirect = _r.indirect;
    ticket = _r.ticket;
    _r.indirect = nullptr;
    _r.ticket = 0;
    return *this;
}

ScopedObservableBase::ObservationTicket::operator bool() const noexcept
{
    return indirect != nullptr && ticket != 0;
}

ScopedObservableBase::ScopedObservableBase()
{
    m_Indirect = std::make_shared<Indirect>();
    m_Indirect->instance = this;
}

ScopedObservableBase::~ScopedObservableBase()
{
    const auto lock = std::lock_guard{m_Indirect->lock};
    m_Indirect->instance = nullptr;
}

ScopedObservableBase::ObservationTicket ScopedObservableBase::AddTicketedObserver(std::function<void()> _callback,
                                                                                  const uint64_t _mask)
{
    if( !_callback || _mask == 0ul )
        return {nullptr, 0};

    auto ticket = m_ObservationTicket++;

    Observer o;
    o.callback = std::move(_callback);
    o.ticket = ticket;
    o.mask = _mask;

    auto new_observers = std::make_shared<std::vector<std::shared_ptr<Observer>>>();
    {
        const auto lock = std::lock_guard{m_ObserversLock};
        if( m_Observers ) {
            new_observers->reserve(m_Observers->size() + 1);
            new_observers->assign(m_Observers->begin(), m_Observers->end());
        }
        new_observers->emplace_back(to_shared_ptr(std::move(o)));
        m_Observers = new_observers;
    }

    return {m_Indirect, ticket};
}

void ScopedObservableBase::AddUnticketedObserver(std::function<void()> _callback, uint64_t _mask)
{
    if( !_callback || _mask == 0ul )
        return;

    Observer o;
    o.callback = std::move(_callback);
    o.ticket = 0;
    o.mask = _mask;

    auto new_observers = std::make_shared<std::vector<std::shared_ptr<Observer>>>();
    {
        const auto lock = std::lock_guard{m_ObserversLock};
        if( m_Observers ) {
            new_observers->reserve(m_Observers->size() + 1);
            new_observers->assign(m_Observers->begin(), m_Observers->end());
        }
        new_observers->emplace_back(to_shared_ptr(std::move(o)));
        m_Observers = new_observers;
    }
}

void ScopedObservableBase::FireObservers(const uint64_t _mask) const
{
    if( _mask == 0ul )
        return;

    std::shared_ptr<std::vector<std::shared_ptr<Observer>>> observers;
    {
        const auto lock = std::lock_guard{m_ObserversLock};
        observers = m_Observers;
    }

    if( observers )
        for( auto &o : *observers )
            if( o->mask & _mask )
                o->callback();
}

void ScopedObservableBase::StopObservation(const uint64_t _ticket)
{
    // keep this shared_ptr after time lock is released, so any observers will be ponentially freed without locking.
    std::shared_ptr<std::vector<std::shared_ptr<Observer>>> old;
    {
        const auto lock = std::lock_guard{m_ObserversLock};
        if( !m_Observers )
            return;
        old = m_Observers;
        for( size_t i = 0, e = old->size(); i != e; ++i ) {
            auto &o = (*old)[i];
            if( o->ticket == _ticket ) {
                auto new_observers = std::make_shared<std::vector<std::shared_ptr<Observer>>>();
                *new_observers = *old;
                new_observers->erase(next(new_observers->begin(), i));
                m_Observers = new_observers;
                return;
            }
        }
    }
}

} // namespace nc::base
