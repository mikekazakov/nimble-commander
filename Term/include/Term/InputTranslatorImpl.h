// Copyright (C) 2013-2020 Michael Kazakov. Subject to GNU General Public License version 3.
#pragma once

#include <span>
#include <Cocoa/Cocoa.h>
#include "InputTranslator.h"

namespace nc::term {

class InputTranslatorImpl : public InputTranslator
{
public:
    void SetOuput( Output _output ) override;
    void ProcessKeyDown( NSEvent *_event )  override;
    void ProcessTextInput(NSString *_str)  override;
    void SetApplicationCursorKeys( bool _enabled ) override;
    
private:
    Output m_Output;
    bool m_ApplicationCursorKeys = false;
};

}
