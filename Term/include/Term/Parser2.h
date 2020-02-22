// Copyright (C) 2020 Michael Kazakov. Subject to GNU General Public License version 3.
#include <variant>
#include <string>
#include <vector>
#include <span>
#include <memory>
#include <optional>

namespace nc::term {

namespace input {
 
enum class Type {
    noop,               // no operation, defined only for conviniency
    text,               // clean unicode text without any control characters, both escaped
                        // and unescaped. payload type - UTF32Text
    line_feed,          // line feed or new line
    horizontal_tab,     // move cursor to next horizontal tab stop
                        // payload type - unsigned
    carriage_return,    // move cursor to the beginning of the horizontal line
    back_space,         // move cursor left by one space
    bell,               // generates a bell tone
    reverse_index,      // move cursor up, scroll if needed
    reset,              // reset the terminal to its initial state
    save_state,         // save cursor position and graphic rendition
    restore_state,      // restore cursor position and graphic rendition
    change_title,       // payload type - Title
    move_cursor,        // payload type - CursorMovement
    erase_in_display,   // payload type - DisplayErasure
    erase_in_line,      // payload type - LineErasure
    insert_lines,       // insert the indicated number of blank lines
                        // payload type - unsigned
    delete_lines,       // delete the indicated number of lines
                        // payload type - unsigned
    delete_characters,  // delete the indicacted number of characters from the cursor position
                        // to the right. payload type - unsigned
};

struct Empty {}; // default empty payload   

struct Title {
    enum Kind {
        IconAndWindow,
        Icon,
        Window
    };
    Kind kind = IconAndWindow;
    std::string title; 
};

struct UTF32Text {
    std::u32string characters; // composed unicode characters 
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

struct Command {
    using Payload = std::variant<Empty, UTF32Text, Title, CursorMovement,
    DisplayErasure, LineErasure, unsigned>;
    Command() noexcept; 
    Command(Type _type) noexcept;
    Command(Type _type, Payload _payload) noexcept;
    
    Type type;
    Payload payload;
};

}

class Parser2
{
public: 
    using Bytes = std::span<const std::byte, std::dynamic_extent>;
    virtual ~Parser2() = default;
    virtual std::vector<input::Command> Parse( Bytes _to_parse ) = 0;
};


namespace input {

inline Command::Command() noexcept :
    Command(Type::noop)
{
}

inline Command::Command(Type _type) noexcept:
    type{_type},
    payload{Empty()}
{
}

inline Command::Command(Type _type, Payload _payload) noexcept:
    type{_type},
    payload{std::move(_payload)}
{
}

}

}
