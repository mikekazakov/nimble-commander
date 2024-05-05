// Copyright (C) 2017-2023 Michael Kazakov. Subject to GNU General Public License version 3.
#include "Settings.h"
#include <Utility/HexadecimalColor.h>
#include <Utility/FontExtras.h>

namespace nc::term {

Settings::~Settings() = default;

std::shared_ptr<Settings> DefaultSettings::SharedDefaultSettings()
{
    [[clang::no_destroy]] static const auto settings = std::make_shared<DefaultSettings>();
    return settings;
}

NSFont *DefaultSettings::Font() const
{
    return [NSFont fontWithStringDescription:@"Menlo-Regular, 13"];
}

NSColor *DefaultSettings::ForegroundColor() const
{
    return [NSColor colorWithHexString:"#BFBFBF"];
}

NSColor *DefaultSettings::BoldForegroundColor() const
{
    return [NSColor colorWithHexString:"#E5E5E5"];
}

NSColor *DefaultSettings::BackgroundColor() const
{
    return [NSColor colorWithHexString:"#000000"];
}

NSColor *DefaultSettings::SelectionColor() const
{
    return [NSColor colorWithHexString:"#E5E5E5"];
}

NSColor *DefaultSettings::CursorColor() const
{
    return [NSColor colorWithHexString:"#666666"];
}

NSColor *DefaultSettings::AnsiColor0() const
{
    return [NSColor colorWithHexString:"#000000"];
}

NSColor *DefaultSettings::AnsiColor1() const
{
    return [NSColor colorWithHexString:"#990000"];
}

NSColor *DefaultSettings::AnsiColor2() const
{
    return [NSColor colorWithHexString:"#00A600"];
}

NSColor *DefaultSettings::AnsiColor3() const
{
    return [NSColor colorWithHexString:"#999900"];
}

NSColor *DefaultSettings::AnsiColor4() const
{
    return [NSColor colorWithHexString:"#0000B2"];
}

NSColor *DefaultSettings::AnsiColor5() const
{
    return [NSColor colorWithHexString:"#B200B2"];
}

NSColor *DefaultSettings::AnsiColor6() const
{
    return [NSColor colorWithHexString:"#00A6B2"];
}

NSColor *DefaultSettings::AnsiColor7() const
{
    return [NSColor colorWithHexString:"#BFBFBF"];
}

NSColor *DefaultSettings::AnsiColor8() const
{
    return [NSColor colorWithHexString:"#666666"];
}

NSColor *DefaultSettings::AnsiColor9() const
{
    return [NSColor colorWithHexString:"#E50000"];
}

NSColor *DefaultSettings::AnsiColorA() const
{
    return [NSColor colorWithHexString:"#00D900"];
}

NSColor *DefaultSettings::AnsiColorB() const
{
    return [NSColor colorWithHexString:"#E5E500"];
}

NSColor *DefaultSettings::AnsiColorC() const
{
    return [NSColor colorWithHexString:"#0000FF"];
}

NSColor *DefaultSettings::AnsiColorD() const
{
    return [NSColor colorWithHexString:"#E500E5"];
}

NSColor *DefaultSettings::AnsiColorE() const
{
    return [NSColor colorWithHexString:"#00E5E5"];
}

NSColor *DefaultSettings::AnsiColorF() const
{
    return [NSColor colorWithHexString:"#E5E5E5"];
}

int DefaultSettings::MaxFPS() const
{
    return 60;
}

enum CursorMode DefaultSettings::CursorMode() const
{
    return CursorMode::BlinkingBlock;
}

bool DefaultSettings::HideScrollbar() const
{
    return false;
}

int DefaultSettings::StartChangesObserving([[maybe_unused]] std::function<void()> _callback)
{
    return 0;
}

void DefaultSettings::StopChangesObserving([[maybe_unused]] int _ticket)
{
}

} // namespace nc::term
