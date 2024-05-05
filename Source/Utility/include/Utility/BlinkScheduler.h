// Copyright (C) 2015-2020 Michael Kazakov. Subject to GNU General Public License version 3.
#pragma once

#include <chrono>
#include <functional>
#include <memory>

namespace nc::utility {

// STA design - do talk from the main thread only
// BlinkScheduler fires callbackes aligned across all BlinkScheduler.
class BlinkScheduler
{
public:
    struct IO {
        virtual ~IO() = default;
        virtual std::chrono::nanoseconds Now() noexcept = 0;
        virtual void Dispatch(std::chrono::nanoseconds _after, std::function<void()> _what) noexcept = 0;
    };
    struct DefaultIO : IO {
        std::chrono::nanoseconds Now() noexcept override;
        void Dispatch(std::chrono::nanoseconds _after, std::function<void()> _what) noexcept override;
        static DefaultIO Instance;
    };

    static constexpr std::chrono::milliseconds DefaultBlinkTime = std::chrono::milliseconds(600);

    // convinience constructor, creates a scheduler with an empty callback
    BlinkScheduler();

    // _on_blink will be fired on each timer run
    BlinkScheduler(std::function<void()> _on_blink,
                   std::chrono::milliseconds _blink_time = DefaultBlinkTime,
                   IO &_io = DefaultIO::Instance);

    BlinkScheduler(const BlinkScheduler &);
    BlinkScheduler(BlinkScheduler &&) noexcept;

    ~BlinkScheduler();
    BlinkScheduler &operator=(const BlinkScheduler &);
    BlinkScheduler &operator=(BlinkScheduler &&) noexcept;

    bool Enabled() const noexcept;
    void Enable(bool _enabled = true) noexcept;

    bool Visible() const noexcept;

private:
    struct Impl;
    std::shared_ptr<Impl> I;
};

} // namespace nc::utility
