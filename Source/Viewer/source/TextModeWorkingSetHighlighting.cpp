// Copyright (C) 2024 Michael Kazakov. Subject to GNU General Public License version 3.
#include "TextModeWorkingSetHighlighting.h"
#include "Highlighting/Client.h"
#include "Log.h"
#include <Base/dispatch_cpp.h>
#include <Utility/Encodings.h>
#include <cassert>
#include <fmt/chrono.h>
#include <stdexcept>

namespace nc::viewer {

// TODO: cover it with unit tests somehow

TextModeWorkingSetHighlighting::TextModeWorkingSetHighlighting(std::shared_ptr<const TextModeWorkingSet> _working_set,
                                                               std::shared_ptr<const std::string> _highlighting_options)
    : m_WorkingSet(std::move(_working_set)), m_HighlightingOptions(std::move(_highlighting_options)),
      m_AsyncQueue(dispatch_queue_create("com.magnumbytes.NimbleCommander.TextModeWorkingSetHighlighting",
                                         DISPATCH_QUEUE_CONCURRENT))
{
    assert(m_WorkingSet);
    assert(m_HighlightingOptions);
    m_Styles.resize(m_WorkingSet->Length(), hl::Style::Default);
}

TextModeWorkingSetHighlighting::~TextModeWorkingSetHighlighting()
{
    dispatch_release(m_AsyncQueue);
}

std::span<const hl::Style> TextModeWorkingSetHighlighting::Styles() const noexcept
{
    return m_Styles;
}

enum TextModeWorkingSetHighlighting::Status TextModeWorkingSetHighlighting::Status() const noexcept
{
    return m_Status;
}

static void MapUTF8ToUTF16(const std::span<const hl::Style> _styles_utf8,
                           const std::span<const char16_t> _chars_utf16,
                           const std::span<hl::Style> _styles_utf16)
{
    assert(_chars_utf16.size() == _styles_utf16.size());

    static const uint16_t g_ReplacementCharacter = 0xFFFD; //  � character

    const size_t utf8_length = _styles_utf8.size();
    const size_t utf16_length = _chars_utf16.size();
    size_t i_utf8 = 0;
    size_t i_utf16 = 0;
    while( i_utf16 < utf16_length && i_utf8 < utf8_length ) {
        const char16_t val = _chars_utf16[i_utf16];
        size_t utf16_delta = 1;
        uint32_t codepoint = 0;

        // decode UTF16 aka Unichars
        if( val <= 0xD7FF || (val >= 0xE000 && val <= 0xFFFF) ) {
            // BMP - just use it
            codepoint = val;
        }
        else {
            // process surrogates
            if( val >= 0xD800 && val <= 0xDBFF ) {
                // leading surrogate
                if( i_utf16 + 1 < utf16_length ) {
                    const char16_t next = _chars_utf16[i_utf16 + 1];
                    if( next >= 0xDC00 && next <= 0xDFFF ) { // ok, normal surrogates
                        codepoint = (((val - 0xD800) << 10) + (next - 0xDC00) + 0x0010000);
                        utf16_delta = 2;
                    }
                    else {
                        codepoint = g_ReplacementCharacter; // corrupted surrogate - without trailing
                    }
                }
                else {
                    codepoint = g_ReplacementCharacter; // torn surrogate pair
                }
            }
            else {
                codepoint = g_ReplacementCharacter; // trailing surrogate found - invalid situation
            }
        }

        // Deduce a length of utf8 chars this codepoint was mapped into
        size_t utf8_delta = 1;
        if( codepoint < 0x0080 ) {
            utf8_delta = 1;
        }
        else if( codepoint <= 0x7FF ) {
            utf8_delta = 2;
        }
        else if( codepoint <= 0xFFFF ) {
            utf8_delta = 3;
        }
        else if( codepoint <= 0x10FFFF ) {
            utf8_delta = 4;
        }

        for( size_t i = i_utf16; i < i_utf16 + utf16_delta; ++i ) {
            _styles_utf16[i] = _styles_utf8[i_utf8];
        }

        i_utf8 += utf8_delta;
        i_utf16 += utf16_delta;
    }
}

void TextModeWorkingSetHighlighting::Highlight(
    std::chrono::milliseconds _sync_timeout,
    std::function<void(std::shared_ptr<const TextModeWorkingSetHighlighting> me)> _on_highlighted)
{
    dispatch_assert_main_queue();

    if( m_Status != Status::Inactive ) {
        throw std::logic_error("TextModeWorkingSetHighlighting::Highlight can only be called once");
    }

    const std::weak_ptr<TextModeWorkingSetHighlighting> weak_me = weak_from_this();
    if( weak_me.expired() ) {
        throw std::logic_error("TextModeWorkingSetHighlighting must be held in a shared pointer");
    }

    const std::shared_ptr<TextModeWorkingSetHighlighting> me = weak_me.lock();

    const size_t utf16_length = m_WorkingSet->Length();
    const char16_t *const utf16_chars = m_WorkingSet->Characters();

    const size_t utf8_maxsz = utf16_length * 4;
    std::vector<char> utf8(utf8_maxsz);
    size_t utf8_len = 0;
    utility::InterpretUnicharsAsUTF8(reinterpret_cast<const uint16_t *>(utf16_chars),
                                     utf16_length,
                                     reinterpret_cast<uint8_t *>(utf8.data()),
                                     utf8_maxsz,
                                     utf8_len,
                                     nullptr);
    utf8.resize(utf8_len);

    m_Status = Status::Working;

    m_Callback = std::move(_on_highlighted);

    Log::Trace("TextModeWorkingSetHighlighting: sending async highlighting request");
    const auto timepoint_start = std::chrono::steady_clock::now();

    nc::viewer::hl::Client::HighlightAsync(
        {utf8.data(), utf8.size()},
        *m_HighlightingOptions,
        [me](std::expected<std::vector<hl::Style>, std::string> _result) { me->Commit(std::move(_result)); },
        m_AsyncQueue);

    if( _sync_timeout > std::chrono::milliseconds{0} ) {
        Log::Trace("TextModeWorkingSetHighlighting: waiting synchronously for a response");

        std::unique_lock lock{m_StatusMut};
        m_StatusCV.wait_for(lock, _sync_timeout, [&] { return m_Status == Status::Done; });
        const auto timepoint_end = std::chrono::steady_clock::now();
        const auto time_spent = std::chrono::duration_cast<std::chrono::milliseconds>(timepoint_end - timepoint_start);

        if( m_Status == Status::Done ) {
            Log::Info(

                "TextModeWorkingSetHighlighting: got asynchronous response in {}, providing highlighting immediately",
                time_spent);
            m_Callback = nullptr;
        }
        else {
            Log::Info(

                "TextModeWorkingSetHighlighting: didn't get an asynchronous response in {}, deferring the highlighting",
                time_spent);
        }
    }
}

void TextModeWorkingSetHighlighting::Commit(std::expected<std::vector<hl::Style>, std::string> _result)
{
    dispatch_assert_background_queue();
    if( _result ) {
        const std::vector<hl::Style> &styles_utf8 = _result.value();
        const size_t utf16_length = m_WorkingSet->Length();
        const char16_t *const utf16_chars = m_WorkingSet->Characters();
        MapUTF8ToUTF16(styles_utf8, {utf16_chars, utf16_length}, m_Styles);
        // Technically speaking the above can be a race condition: one thread can read from the styles and this thread
        // can write there without synchronization. However the worst thing can happen here would be a partial
        // highlighting for a very short period of time, which is acceptable.
    }

    {
        const std::lock_guard lock{m_StatusMut};
        m_Status = Status::Done;
    }
    m_StatusCV.notify_one();

    dispatch_to_main_queue([me = shared_from_this()] { me->Notify(); });
}

void TextModeWorkingSetHighlighting::Notify()
{
    dispatch_assert_main_queue();
    if( m_Callback ) {
        m_Callback(shared_from_this());
        m_Callback = nullptr;
    }
}

std::shared_ptr<const TextModeWorkingSet> TextModeWorkingSetHighlighting::WorkingSet() const noexcept
{
    return m_WorkingSet;
}

} // namespace nc::viewer
