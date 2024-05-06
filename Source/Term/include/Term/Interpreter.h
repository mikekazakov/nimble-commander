// Copyright (C) 2020-2023 Michael Kazakov. Subject to GNU General Public License version 3.
#pragma once

#include <span>
#include <functional>

#include "Parser.h"
#include "InputTranslator.h"
#include "CursorMode.h"

namespace nc::term {

class Interpreter
{
public:
    enum class RequestedMouseEvents {
        None,           // no mouse events - default
        X10,            // only mouse press
        Normal,         // press/release
        ButtonTracking, // press->drag->release
        Any             // press/release/drag/motion
    };
    enum class TitleKind {
        Icon,
        Window
    };

    using Bytes = std::span<const std::byte>;
    using Input = std::span<const input::Command>;
    using Output = std::function<void(Bytes _bytes)>;
    using Bell = std::function<void()>;
    using TitleChanged = std::function<void(const std::string &_title, TitleKind _kind)>;
    using ShownCursorChanged = std::function<void(bool _shown)>;
    using CursorStyleChanged = std::function<void(std::optional<CursorMode> _style)>;
    using RequstedMouseEventsChanged = std::function<void(RequestedMouseEvents _events)>;

    virtual ~Interpreter() = default;

    virtual void SetScreenResizeAllowed(bool _allow) = 0;
    virtual void SetInputTranslator(InputTranslator *_input_translator) = 0;
    virtual void SetOuput(Output _output) = 0;
    virtual void SetBell(Bell _bell) = 0;
    virtual void SetTitle(TitleChanged _title) = 0;
    virtual void SetShowCursorChanged(ShownCursorChanged _on_show_cursor_changed) = 0;
    virtual void SetCursorStyleChanged(CursorStyleChanged _on_cursor_style_changed) = 0;
    virtual void SetRequstedMouseEventsChanged(RequstedMouseEventsChanged _on_events_changed) = 0;

    virtual void Interpret(Input _to_interpret) = 0;
    virtual void NotifyScreenResized() = 0;

    virtual bool ScreenResizeAllowed() = 0;
    virtual bool ShowCursor() = 0;
};

} // namespace nc::term
