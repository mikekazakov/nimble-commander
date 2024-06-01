// Copyright (C) 2024 Michael Kazakov. Subject to GNU General Public License version 3.
#include "TextModeWorkingSetHighlighting.h"
#include "Highlighting/Client.h"
#include <Utility/Encodings.h>
#include <stdexcept>
#include <assert.h>

namespace nc::viewer {

TextModeWorkingSetHighlighting::TextModeWorkingSetHighlighting(std::shared_ptr<const TextModeWorkingSet> _working_set,
                                                               std::shared_ptr<const std::string> _highlighting_options)
    : m_WorkingSet(std::move(_working_set)), m_HighlightingOptions(std::move(_highlighting_options))
{
    assert(m_WorkingSet);
    assert(m_HighlightingOptions);
    m_Styles.resize(m_WorkingSet->Length(), hl::Style::Default);
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

// TODO: support async operation
void TextModeWorkingSetHighlighting::Highlight(
    std::chrono::milliseconds _sync_timeout,
    std::function<void(std::shared_ptr<const TextModeWorkingSetHighlighting> me)> _on_highlighted)
{
    (void)_sync_timeout;
    (void)_on_highlighted;

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
    InterpretUnicharsAsUTF8(reinterpret_cast<const uint16_t *>(utf16_chars),
                            utf16_length,
                            reinterpret_cast<uint8_t *>(utf8.data()),
                            utf8_maxsz,
                            utf8_len,
                            nullptr);
    utf8.resize(utf8_len);

    m_Status = Status::Working;

    hl::Client client;
    const std::vector<hl::Style> styles_utf8 = client.Highlight({utf8.data(), utf8.size()}, *m_HighlightingOptions);

    MapUTF8ToUTF16(styles_utf8, {utf16_chars, utf16_length}, m_Styles);

    m_Status = Status::Done;
}

std::shared_ptr<const TextModeWorkingSet> TextModeWorkingSetHighlighting::WorkingSet() const noexcept
{
    return m_WorkingSet;
}

} // namespace nc::viewer
