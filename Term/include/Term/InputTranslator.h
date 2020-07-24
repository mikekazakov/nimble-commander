// Copyright (C) 2013-2020 Michael Kazakov. Subject to GNU General Public License version 3.
#pragma once

#ifdef __OBJC__
#include <Cocoa/Cocoa.h>
#else
#include <Utility/NSCppDeclarations.h>
#endif

#include <span>

namespace nc::term {

class InputTranslator
{
public:
    using Bytes = std::span<const std::byte>;
    using Output = std::function<void(Bytes _bytes)>;
    virtual ~InputTranslator() = default;
    virtual void SetOuput( Output _output ) = 0;
    virtual void ProcessKeyDown( NSEvent *_event ) = 0;
    virtual void ProcessTextInput( NSString *_str ) = 0;
    virtual void SetApplicationCursorKeys( bool _enabled ) = 0;
};

}
