// Copyright (C) 2013-2023 Michael Kazakov. Subject to GNU General Public License version 3.
#pragma once

#ifdef __OBJC__
#include <Cocoa/Cocoa.h>
#else
#include <Utility/NSCppDeclarations.h>
#endif

#include <span>
#include <string_view>
#include <functional>

namespace nc::term {

class InputTranslator
{
public:
    using Bytes = std::span<const std::byte>;
    using Output = std::function<void(Bytes _bytes)>;
    struct MouseEvent;
    enum class MouseReportingMode;
    virtual ~InputTranslator() = default;
    virtual void SetOuput(Output _output) = 0;
    virtual void ProcessKeyDown(NSEvent *_event) = 0;
    virtual void ProcessTextInput(NSString *_str) = 0;
    virtual void ProcessMouseEvent(MouseEvent _event) = 0;
    virtual void ProcessPaste(std::string_view _utf8) = 0;
    virtual void SetApplicationCursorKeys(bool _enabled) = 0;
    virtual void SetBracketedPaste(bool _bracketed) = 0;
    virtual void SetMouseReportingMode(MouseReportingMode _mode) = 0;
};

struct InputTranslator::MouseEvent {
    enum Type : short {
        LDown,
        LDrag,
        LUp,
        MDown,
        MDrag,
        MUp,
        RDown,
        RDrag,
        RUp,
        Motion,
    };

    // coordinates are zero-based
    short x = 0;
    short y = 0;
    Type type = LDown;
    bool shift : 1 = false;
    bool alt : 1 = false;
    bool control : 1 = false;
};

enum class InputTranslator::MouseReportingMode {
    X10,
    Normal,
    UTF8,
    SGR
};

} // namespace nc::term
