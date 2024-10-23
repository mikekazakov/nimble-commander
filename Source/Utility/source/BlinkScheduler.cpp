// Copyright (C) 2015-2023 Michael Kazakov. Subject to GNU General Public License version 3.

#include "../include/Utility/BlinkScheduler.h"
#include <Base/mach_time.h>
#include <Base/dispatch_cpp.h>
#include <stdexcept>

namespace nc::utility {

using namespace std::chrono_literals;

[[clang::no_destroy]] BlinkScheduler::BlinkScheduler::DefaultIO BlinkScheduler::DefaultIO::Instance;

struct BlinkScheduler::Impl : std::enable_shared_from_this<Impl> {
    void Fire();
    void Schedule();
    bool VisibleNow() const noexcept;
    std::chrono::nanoseconds NextFireAfter() const noexcept;

    std::function<void()> m_OnBlink;
    std::chrono::milliseconds m_BlinkTime;
    IO *m_IO;
    bool m_Enabled = false;
    bool m_PhaseVisible = true;
    bool m_Scheduled = false;
};

BlinkScheduler::BlinkScheduler() : BlinkScheduler([] {}, DefaultBlinkTime, DefaultIO::Instance)
{
}

BlinkScheduler::BlinkScheduler(std::function<void()> _on_blink, std::chrono::milliseconds _blink_time, IO &_io)
    : I(std::make_shared<Impl>())
{
    I->m_OnBlink = std::move(_on_blink);
    I->m_BlinkTime = _blink_time;
    I->m_IO = &_io;

    if( !I->m_OnBlink )
        throw std::invalid_argument("BlinkScheduler _on_blink can't be empty");
    if( I->m_BlinkTime <= 0ms )
        throw std::invalid_argument("BlinkScheduler _blink_time must be zero");
}

BlinkScheduler::BlinkScheduler(const BlinkScheduler &_rhs) : I(std::make_shared<Impl>())
{
    I->m_OnBlink = _rhs.I->m_OnBlink;
    I->m_BlinkTime = _rhs.I->m_BlinkTime;
    I->m_IO = _rhs.I->m_IO;
    I->m_Enabled = false;
    I->m_PhaseVisible = _rhs.I->m_PhaseVisible;
    I->m_Scheduled = false;
}

BlinkScheduler::BlinkScheduler(BlinkScheduler &&) noexcept = default;

BlinkScheduler::~BlinkScheduler() = default;

BlinkScheduler &BlinkScheduler::operator=(const BlinkScheduler &_rhs)
{
    if( this != &_rhs )
        *this = BlinkScheduler(_rhs);
    return *this;
}

BlinkScheduler &BlinkScheduler::operator=(BlinkScheduler &&) noexcept = default;

bool BlinkScheduler::Enabled() const noexcept
{
    return I->m_Enabled;
}

void BlinkScheduler::Enable(bool _enabled) noexcept
{
    if( I->m_Enabled == _enabled )
        return;

    if( I->m_Enabled ) { // disable
        I->m_Enabled = false;
    }
    else { // enable
        I->m_Enabled = true;
        if( !I->m_Scheduled ) {
            I->m_PhaseVisible = I->VisibleNow();
            I->Schedule();
        }
    }
}

bool BlinkScheduler::Visible() const noexcept
{
    if( !I->m_Enabled )
        return true;

    return I->m_PhaseVisible;
}

void BlinkScheduler::Impl::Schedule()
{
    assert(m_Scheduled == false);
    assert(m_Enabled == true);

    const auto after = NextFireAfter();
    const std::weak_ptr<Impl> impl = weak_from_this();
    m_IO->Dispatch(after, [impl] {
        if( auto me = impl.lock() )
            me->Fire();
    });
    m_Scheduled = true;
}

void BlinkScheduler::Impl::Fire()
{
    m_Scheduled = false;
    if( !m_Enabled ) {
        // was disabled after scheduled - don't do anything
        return;
    }

    m_PhaseVisible = !m_PhaseVisible;

    m_OnBlink();

    if( !m_Enabled ) {
        // now check for reentrancy shenenigans
        return;
    }

    Schedule();
}

std::chrono::nanoseconds BlinkScheduler::Impl::NextFireAfter() const noexcept
{
    const auto now = m_IO->Now();
    const auto div = std::chrono::duration_cast<std::chrono::milliseconds>(now) / m_BlinkTime;
    return ((div + 1) * m_BlinkTime) - now;
}

bool BlinkScheduler::Impl::VisibleNow() const noexcept
{
    const auto now = m_IO->Now();
    auto n = std::chrono::duration_cast<std::chrono::milliseconds>(now) / m_BlinkTime;
    return n % 2 == 0;
}

std::chrono::nanoseconds BlinkScheduler::DefaultIO::Now() noexcept
{
    return base::machtime();
}

void BlinkScheduler::DefaultIO::Dispatch(std::chrono::nanoseconds _after, std::function<void()> _what) noexcept
{
    dispatch_to_main_queue_after(_after, std::move(_what));
}

} // namespace nc::utility
