// Copyright (C) 2020 Michael Kazakov. Subject to GNU General Public License version 3.
#pragma once
#include <variant>
#include <string>
#include <vector>
#include <span>
#include <memory>
#include <optional>

namespace nc::term {

namespace input {
 
enum class Type {
    noop,                   // no operation, defined only for conviniency
    text,                   // clean unicode text without any control characters, both escaped
                            // and unescaped. payload type - UTF8Text
    line_feed,              // line feed or new line
    horizontal_tab,         // move cursor to next horizontal tab stop.
                            // negative values means backward direction.
                            // payload type - signed
    carriage_return,        // move cursor to the beginning of the horizontal line
    back_space,             // move cursor left by one space
    bell,                   // generates a bell tone
    reverse_index,          // move cursor up, scroll if needed
    reset,                  // reset the terminal to its initial state
    save_state,             // save cursor position and graphic rendition
    restore_state,          // restore cursor position and graphic rendition
    screen_alignment_test,  // DECALN — screen alignment pattern
    change_title,           // payload type - Title
    move_cursor,            // payload type - CursorMovement
    erase_in_display,       // payload type - DisplayErasure
    erase_in_line,          // payload type - LineErasure
    insert_lines,           // insert the indicated number of blank lines
                            // payload type - unsigned
    delete_lines,           // delete the indicated number of lines
                            // payload type - unsigned
    delete_characters,      // delete the indicated number of characters from the cursor position
                            // to the right. payload type - unsigned
    scroll_lines,           // scroll up(positive) or down(negative) the indicated number of lines
                            // payload type - signed
    erase_characters,       // erase the indicated number of characters on current line,
                            // from the cursor position to the right. payload type - unsigned
    repeat_last_character,  // repeat the last output character the indicated number of times.
                            // payload type - unsigned
    report,                 // ask for the terminal's status
                            // payload type - DeviceReport
    change_mode,            // payload type - ModeChange
    set_scrolling_region    // payload type - ScrollingRegion
};

struct None {
};

struct Title {
    enum Kind {
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
    enum Positioning {
        Absolute,
        Relative
    };
    Positioning positioning = Absolute;
    std::optional<int> x;
    std::optional<int> y;
};

struct DisplayErasure
{
    enum Area {
        FromCursorToDisplayEnd,
        FromDisplayStartToCursor,
        WholeDisplay,
        WholeDisplayWithScrollback
    };
    Area what_to_erase = FromCursorToDisplayEnd;
};

struct LineErasure
{
    enum Area {
        FromCursorToLineEnd,
        FromLineStartToCursor,
        WholeLine
    };
    Area what_to_erase = FromCursorToLineEnd;
};

struct ModeChange
{
    enum Kind {
        Insert, // Insert Mode / Replace Mode (default) [IRM]
        NewLine, // New Line Mode / Line Feed Mode (default) [LNM]
        Column132, // 132 Column Mode / 80 Column Mode (default) [DECCOLM]
        Origin, // Origin Cursor Mode / Normal Cursor Mode (default) [DECOM]
        AutoWrap, // Auto-wrap Mode / No Auto-wrap Mode [DECAWM]
    };
    Kind mode = Insert;
    bool status = true;
};

struct DeviceReport
{
    enum Kind {
        TerminalId,
        DeviceStatus,
        CursorPosition
    };
    Kind mode = TerminalId;
};

struct ScrollingRegion
{
    struct Range {
        int top; // closed range end, [
        int bottom; // open range end, )
    };
    std::optional<Range> range;
};

struct Command {
    using Payload = std::variant<None, signed, unsigned, UTF8Text, Title, CursorMovement,
    DisplayErasure, LineErasure, ModeChange, DeviceReport, ScrollingRegion>;
    Command() noexcept; 
    Command(Type _type) noexcept;
    Command(Type _type, Payload _payload) noexcept;
    
    Type type;
    Payload payload;
};

std::string VerboseDescription(const Command & _command);

}

class Parser2
{
public: 
    using Bytes = std::span<const std::byte>;
    virtual ~Parser2() = default;
    virtual std::vector<input::Command> Parse( Bytes _to_parse ) = 0;
};


namespace input {

inline Command::Command() noexcept :
    Command(Type::noop)
{
}

inline Command::Command(Type _type) noexcept:
    type{_type}
{
}

inline Command::Command(Type _type, Payload _payload) noexcept:
    type{_type},
    payload{std::move(_payload)}
{
}

}

}
