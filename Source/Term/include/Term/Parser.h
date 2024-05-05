// Copyright (C) 2020-2023 Michael Kazakov. Subject to GNU General Public License version 3.
#pragma once
#include <variant>
#include <string>
#include <vector>
#include <span>
#include <memory>
#include <optional>
#include <iostream>
#include <stdint.h>
#include "Color.h"
#include "CursorMode.h"

// RTFM:
// http://ascii-table.com/ansi-escape-sequences.php
// http://en.wikipedia.org/wiki/ANSI_escape_code
// http://graphcomp.com/info/specs/ansi_col.html
// http://vt100.net/docs/vt100-ug/chapter3.html
// https://vt100.net/docs/tp83/appendixb.html
// http://www.real-world-systems.com/docs/ANSIcode.html
// https://www.xfree86.org/4.5.0/ctlseqs.html
// http://www.ecma-international.org/publications/files/ECMA-ST/Ecma-048.pdf

// xterm:
// http://rtfm.etla.org/xterm/ctlseq.html
// https://invisible-island.net/xterm/ctlseqs/ctlseqs.html

// https://invisible-island.net/vttest/vttest.html

// https://onlineunicodetools.com/add-combining-characters

namespace nc::term {

namespace input {

enum class Type : uint8_t {
    noop,                     // no operation, defined only for conviniency
    text,                     // clean unicode text without any control characters, both escaped
                              // and unescaped. payload type - UTF8Text
    line_feed,                // line feed or new line
    horizontal_tab,           // move cursor to next horizontal tab stop.
                              // negative values means backward direction.
                              // payload type - signed
    carriage_return,          // move cursor to the beginning of the horizontal line
    back_space,               // move cursor left by one space
    bell,                     // generates a bell tone
    reverse_index,            // move cursor up, scroll if needed
    reset,                    // reset the terminal to its initial state
    save_state,               // save cursor position and graphic rendition
    restore_state,            // restore cursor position and graphic rendition
    screen_alignment_test,    // DECALN — screen alignment pattern
    change_title,             // payload type - Title
    manipulate_title,         // payload type - WindowTitleManipulation
    move_cursor,              // payload type - CursorMovement
    erase_in_display,         // payload type - DisplayErasure
    erase_in_line,            // payload type - LineErasure
    insert_lines,             // insert the indicated number of blank lines
                              // payload type - unsigned
    delete_lines,             // delete the indicated number of lines
                              // payload type - unsigned
    delete_characters,        // delete the indicated number of characters from the cursor position
                              // to the right. payload type - unsigned
    insert_characters,        // insert blank characters.
                              // payload type - unsigned
    scroll_lines,             // scroll up(positive) or down(negative) the indicated number of lines
                              // payload type - signed
    erase_characters,         // erase the indicated number of characters on current line,
                              // from the cursor position to the right. payload type - unsigned
    repeat_last_character,    // repeat the last output character the indicated number of times.
                              // payload type - unsigned
    report,                   // ask for the terminal's status
                              // payload type - DeviceReport
    change_mode,              // payload type - ModeChange
    set_scrolling_region,     // payload type - ScrollingRegion
    clear_tab,                // payload type - TabClear
    set_tab,                  // set one horizontal stop at the active position.
    set_character_attributes, // payload type - CharacterAttributes
    select_character_set,     // payload type unsigned (0 - G0, 1 - G1, 2 - G2, 3 - G3)
    designate_character_set,  // payload type - CharacterSetDesignation
    set_cursor_style          // payload type - CursorStyle
};

struct None {
};

struct Title {
    enum Kind : uint8_t {
        IconAndWindow,
        Icon,
        Window
    };
    Kind kind = IconAndWindow;
    std::string title;
};

struct UTF8Text {
    std::string characters;
};

struct CursorMovement {
    enum Positioning : uint8_t {
        Absolute,
        Relative
    };
    Positioning positioning = Absolute;
    std::optional<int> x;
    std::optional<int> y;
};

struct DisplayErasure {
    enum Area : uint8_t {
        FromCursorToDisplayEnd,
        FromDisplayStartToCursor,
        WholeDisplay,
        WholeDisplayWithScrollback
    };
    Area what_to_erase = FromCursorToDisplayEnd;
};

struct LineErasure {
    enum Area : uint8_t {
        FromCursorToLineEnd,
        FromLineStartToCursor,
        WholeLine
    };
    Area what_to_erase = FromCursorToLineEnd;
};

struct ModeChange {
    enum Kind : uint8_t {
        Insert,                           // Insert Mode / Replace Mode [IRM]
        NewLine,                          // New Line Mode / Line Feed Mode [LNM]
        Column132,                        // 132 Column Mode / 80 Column Mode [DECCOLM]
        Origin,                           // Origin Cursor Mode / Normal Cursor Mode [DECOM]
        AutoWrap,                         // Auto-wrap Mode / No Auto-wrap Mode [DECAWM]
        ReverseVideo,                     // Reverse Video / Normal Video [DECSCNM]
        SmoothScroll,                     // Smooth (Slow) Scroll / Jump (Fast) Scroll [DECSCLM]
        ApplicationCursorKeys,            // Application Cursor Keys / Normal Cursor Keys [DECCKM]
        AlternateScreenBuffer,            // Alternate Screen Buffer / Normal Screen Buffer
        AlternateScreenBuffer1049,        // as AlternateScreenBuffer, but clears alternate screen
        BlinkingCursor,                   // Start Blinking Cursor / Stop Blinking Cursor
        ShowCursor,                       // Show Cursor / Hide Cursor [DECTCEM]
        AutoRepeatKeys,                   // Auto-repeat Keys / No Auto-repeat Keys [DECARM]
        SendMouseXYOnPress,               // Do send / don't send (X10 compatibility - xterm)
        SendMouseXYOnPressAndRelease,     // Do send / don't send (xterm)
        SendMouseXYOnPressDragAndRelease, // Do send / don't send (xterm)
        SendMouseXYAnyEvent,              // Use All Motion Mouse Tracking / Don't use All Motion Mouse Tracking
                                          // (xterm)
        SendMouseReportUFT8,              // Enable UTF-8 Mouse Mode / Disable UTF-8 Mouse Mode (xterm)
        SendMouseReportSGR,               // Enable SGR Mouse Mode / Disable SGR Mouse Mode (xterm)
        BracketedPaste,                   // Enable bracketed paste mode/ Disable bracketed paste mode (xterm)
    };
    Kind mode = Insert;
    bool status = false;
};

struct DeviceReport {
    enum Kind : uint8_t {
        TerminalId,
        DeviceStatus,
        CursorPosition
    };
    Kind mode = TerminalId;
};

struct ScrollingRegion {
    struct Range {
        int top;    // closed range end, [
        int bottom; // open range end, )
    };
    std::optional<Range> range;
};

struct TabClear {
    enum Kind : uint8_t {
        All,
        CurrentColumn
    };
    Kind mode = All;
};

struct CharacterAttributes {
    enum Kind : uint8_t {
        Normal,
        Bold,
        Faint,
        Italicized,
        Underlined,
        Blink,
        Inverse,
        Invisible,
        Crossed,
        DoublyUnderlined,
        NotBoldNotFaint,
        NotItalicized,
        NotUnderlined,
        NotBlink,
        NotInverse,
        NotInvisible,
        NotCrossed,
        ForegroundColor, // specified in 'color'
        ForegroundDefault,
        BackgroundColor, // specified in 'color'
        BackgroundDefault,
    };
    Kind mode = Normal;
    Color color; // For ForegroundColor and BackgroundColor

    constexpr auto operator<=>(const CharacterAttributes &rhs) const noexcept = default;
};

struct CharacterSetDesignation {
    enum Set : uint8_t {
        DECSpecialGraphics,                      // '0'
        AlternateCharacterROMStandardCharacters, // '1'
        AlternateCharacterROMSpecialGraphics,    // '2'
        UK,                                      // 'A'
        USASCII                                  // 'B'
    };
    uint8_t target = 0; // 0 - G0, 1 - G1 etc
    Set set = DECSpecialGraphics;
};

struct TitleManipulation {
    enum Kind : uint8_t {
        Both,
        Icon,
        Window
    };
    enum Operation : uint8_t {
        Save,
        Restore
    };
    Kind target = Both;
    Operation operation = Save;
};

struct CursorStyle {
    std::optional<CursorMode> style = std::nullopt;
};

struct Command {
    using Payload = std::variant<None,
                                 signed,
                                 unsigned,
                                 UTF8Text,
                                 Title,
                                 CursorMovement,
                                 DisplayErasure,
                                 LineErasure,
                                 ModeChange,
                                 DeviceReport,
                                 ScrollingRegion,
                                 TabClear,
                                 CharacterAttributes,
                                 CharacterSetDesignation,
                                 TitleManipulation,
                                 CursorStyle>;
    Command() noexcept;
    Command(Type _type) noexcept;
    Command(Type _type, Payload _payload) noexcept;

    Type type;
    Payload payload;
};

std::string VerboseDescription(const Command &_command);
void LogCommands(std::span<const Command> _commands);
std::string FormatRawInput(std::span<const std::byte> _input);

} // namespace input

class Parser
{
public:
    using Bytes = std::span<const std::byte>;
    virtual ~Parser() = default;
    virtual std::vector<input::Command> Parse(Bytes _to_parse) = 0;
};

namespace input {

inline Command::Command() noexcept : Command(Type::noop)
{
}

inline Command::Command(Type _type) noexcept : type{_type}
{
}

inline Command::Command(Type _type, Payload _payload) noexcept : type{_type}, payload{std::move(_payload)}
{
}

} // namespace input

} // namespace nc::term
