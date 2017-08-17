/* Copyright (c) 2016 Michael G. Kazakov
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
#include <Habanero/algo.h>
#include <Habanero/Observable.h>

using namespace std;

ObservableBase::ObservationTicket::ObservationTicket() noexcept:
    instance(nullptr),
    ticket(0)
{
}

ObservableBase::ObservationTicket::ObservationTicket(ObservableBase *_inst, unsigned long _ticket) noexcept:
    instance(_inst),
    ticket(_ticket)
{
}

ObservableBase::ObservationTicket::ObservationTicket(ObservationTicket &&_r) noexcept:
    instance(_r.instance),
    ticket(_r.ticket)
{
    _r.instance = nullptr;
    _r.ticket = 0;
}

ObservableBase::ObservationTicket::~ObservationTicket()
{
    if( *this )
        instance->StopObservation(ticket);
}

const ObservableBase::ObservationTicket &ObservableBase::ObservationTicket::operator=(ObservableBase::ObservationTicket &&_r)
{
    if( *this )
        instance->StopObservation(ticket);
    instance = _r.instance;
    ticket = _r.ticket;
    _r.instance = nullptr;
    _r.ticket = 0;
    return *this;
}

ObservableBase::ObservationTicket::operator bool() const noexcept
{
    return instance != nullptr && ticket != 0;
}

ObservableBase::~ObservableBase()
{
    LOCK_GUARD(m_ObserversLock) {
        if( m_Observers && !m_Observers->empty() )
            printf("ObservableBase %p was destroyed with alive observers! This will lead to UB or crash.\n", this);
    }
}

ObservableBase::ObservationTicket ObservableBase::AddObserver( function<void()> _callback, const uint64_t _mask )
{
    if( !_callback || _mask == 0 )
        return {nullptr, 0};
    
    auto ticket = m_ObservationTicket++;
    
    Observer o;
    o.callback = move(_callback);
    o.ticket = ticket;
    o.mask = _mask;
    
    auto new_observers = make_shared<vector<shared_ptr<Observer>>>();
    LOCK_GUARD(m_ObserversLock) {
        if( m_Observers ) {
            new_observers->reserve( m_Observers->size() + 1 );
            new_observers->assign( m_Observers->begin(), m_Observers->end() );
        }
        new_observers->emplace_back( to_shared_ptr( move(o) ) );
        m_Observers = new_observers;
    }
    
    return ObservationTicket(this, ticket);
}

void ObservableBase::FireObservers( const uint64_t _mask ) const
{
    if( !_mask ) // meaningless call
        return;

    shared_ptr<vector<shared_ptr<Observer>>> observers;
    LOCK_GUARD(m_ObserversLock) {
        observers = m_Observers;
    }
    
    if( observers )
        for( auto &o: *observers )
            if( o->mask & _mask )
                o->callback();
}

void ObservableBase::StopObservation(const uint64_t _ticket)
{
    // keep this shared_ptr after time lock is released, so any observers will be ponentially freed without locking.
    shared_ptr<vector<shared_ptr<Observer>>> old;
    LOCK_GUARD(m_ObserversLock) {
        if( !m_Observers )
            return;
        old = m_Observers;
        for( size_t i = 0, e = old->size(); i != e; ++i ) {
            auto &o = (*old)[i];
            if( o->ticket == _ticket ) {
                auto new_observers = make_shared<vector<shared_ptr<Observer>>>();
                *new_observers = *old;
                new_observers->erase( next(new_observers->begin(), i) );
                m_Observers = new_observers;
                return;
            }
        }
    }
}
