// Copyright (C) 2020 Michael Kazakov. Subject to GNU General Public License version 3.
#pragma once

#include <span>
#include <functional>

#include "Parser2.h"
#include "InputTranslator.h"

namespace nc::term {

class Interpreter
{
public:
    using Bytes = std::span<const std::byte>;
    using Input = std::span<const input::Command>;
    using Output = std::function<void(Bytes _bytes)>;
    using Bell = std::function<void()>;
    using Title = std::function<void(const std::string &_title, bool _icon, bool _window)>;

    virtual ~Interpreter() = default;
    virtual void Interpret( Input _to_interpret ) = 0;
    virtual void SetOuput( Output _output ) = 0;
    virtual void SetBell( Bell _bell ) = 0;
    virtual void SetTitle( Title _title ) = 0;
    virtual bool ScreenResizeAllowed() = 0;
    virtual void SetScreenResizeAllowed( bool _allow ) = 0;
    virtual void SetInputTranslator( InputTranslator *_input_translator ) = 0;
    virtual void NotifyScreenResized() = 0;
};

}
