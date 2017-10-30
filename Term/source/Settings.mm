// Copyright (C) 2017 Michael Kazakov. Subject to GNU General Public License version 3.
#include "Settings.h"
#include <Utility/HexadecimalColor.h>
#include <Utility/FontExtras.h>


namespace nc::term {
    
Settings::~Settings()
{
}
    
shared_ptr<Settings> DefaultSettings::SharedDefaultSettings()
{
    static const auto settings = make_shared<DefaultSettings>();
    return settings;
}

NSFont *DefaultSettings::Font() const
{
    return [NSFont fontWithStringDescription:@"Menlo-Regular, 13"];
}

NSColor *DefaultSettings::ForegroundColor() const
{
    return [NSColor colorWithHexStdString:"#BFBFBF"];
}

NSColor *DefaultSettings::BoldForegroundColor() const
{
    return [NSColor colorWithHexStdString:"#E5E5E5"];
}

NSColor *DefaultSettings::BackgroundColor() const
{
    return [NSColor colorWithHexStdString:"#000000"];
}

NSColor *DefaultSettings::SelectionColor() const
{
    return [NSColor colorWithHexStdString:"#E5E5E5"];
}

NSColor *DefaultSettings::CursorColor() const
{
    return [NSColor colorWithHexStdString:"#666666"];
}

NSColor *DefaultSettings::AnsiColor0() const
{
    return [NSColor colorWithHexStdString:"#000000"];
}

NSColor *DefaultSettings::AnsiColor1() const
{
    return [NSColor colorWithHexStdString:"#990000"];
}

NSColor *DefaultSettings::AnsiColor2() const
{
    return [NSColor colorWithHexStdString:"#00A600"];
}

NSColor *DefaultSettings::AnsiColor3() const
{
    return [NSColor colorWithHexStdString:"#999900"];
}

NSColor *DefaultSettings::AnsiColor4() const
{
    return [NSColor colorWithHexStdString:"#0000B2"];
}

NSColor *DefaultSettings::AnsiColor5() const
{
    return [NSColor colorWithHexStdString:"#B200B2"];
}

NSColor *DefaultSettings::AnsiColor6() const
{
    return [NSColor colorWithHexStdString:"#00A6B2"];
}

NSColor *DefaultSettings::AnsiColor7() const
{
    return [NSColor colorWithHexStdString:"#BFBFBF"];
}

NSColor *DefaultSettings::AnsiColor8() const
{
    return [NSColor colorWithHexStdString:"#666666"];
}

NSColor *DefaultSettings::AnsiColor9() const
{
    return [NSColor colorWithHexStdString:"#E50000"];
}

NSColor *DefaultSettings::AnsiColorA() const
{
    return [NSColor colorWithHexStdString:"#00D900"];
}

NSColor *DefaultSettings::AnsiColorB() const
{
    return [NSColor colorWithHexStdString:"#E5E500"];
}

NSColor *DefaultSettings::AnsiColorC() const
{
    return [NSColor colorWithHexStdString:"#0000FF"];
}

NSColor *DefaultSettings::AnsiColorD() const
{
    return [NSColor colorWithHexStdString:"#E500E5"];
}

NSColor *DefaultSettings::AnsiColorE() const
{
    return [NSColor colorWithHexStdString:"#00E5E5"];
}

NSColor *DefaultSettings::AnsiColorF() const
{
    return [NSColor colorWithHexStdString:"#E5E5E5"];
}

int DefaultSettings::MaxFPS() const
{
    return 60;
}

enum CursorMode DefaultSettings::CursorMode() const
{
    return CursorMode::Block;
}

bool DefaultSettings::HideScrollbar() const
{
    return false;
}

int DefaultSettings::StartChangesObserving( function<void()> _callback )
{
    return 0;
}

void DefaultSettings::StopChangesObserving( int _ticket )
{
}
   
}
