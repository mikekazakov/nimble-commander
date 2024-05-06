// Copyright (C) 2013-2020 Michael Kazakov. Subject to GNU General Public License version 3.
#pragma once

#include <span>
#include <Cocoa/Cocoa.h>
#include "InputTranslator.h"

namespace nc::term {

class InputTranslatorImpl : public InputTranslator
{
public:
    InputTranslatorImpl();
    void SetOuput(Output _output) override;
    void ProcessKeyDown(NSEvent *_event) override;
    void ProcessTextInput(NSString *_str) override;
    void ProcessMouseEvent(MouseEvent _event) override;
    void ProcessPaste(std::string_view _utf8) override;
    void SetApplicationCursorKeys(bool _enabled) override;
    void SetBracketedPaste(bool _bracketed) override;
    void SetMouseReportingMode(MouseReportingMode _mode) override;

private:
    Output m_Output;
    bool m_ApplicationCursorKeys = false;
    bool m_BracketedPaste = false;
    MouseReportingMode m_ReportingMode = MouseReportingMode::Normal;
    std::string (*m_MouseReportFormatter)(InputTranslator::MouseEvent _event) noexcept = nullptr;
};

} // namespace nc::term
