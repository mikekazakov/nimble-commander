// Copyright (C) 2025 Michael Kazakov. Subject to GNU General Public License version 3.
#include <Utility/Localizable.h>
#include "Internal.h"

// NB! Do NOT include this file into the unity build lest it break Xcode's automatic extraction of localizable strings.

namespace nc::utility::localizable {

NSString *SpdLogWindowAutoscrollToTheBottomToolTip()
{
    return NSLocalizedString(@"Autoscroll to the bottom", "SpdLog window: autoscroll button tooltip");
}

NSString *SpdLogWindowClearTheLogsToolTip()
{
    return NSLocalizedString(@"Clear the logs", "SpdLog window: clear button tooltip");
}

NSString *SpdLogWindowAdjustTheLoggingSettingsToolTip()
{
    return NSLocalizedString(@"Adjust the logging settings", "SpdLog window: settings button tooltip");
}

NSString *SpdLogWindowTitle()
{
    return NSLocalizedString(@"Logs", "SpdLog window: window title");
}

NSString *SpdLogWindowLevelTrace()
{
    return NSLocalizedString(@"Trace", "SpdLog window: logging level");
}

NSString *SpdLogWindowLevelDebug()
{
    return NSLocalizedString(@"Debug", "SpdLog window: logging level");
}

NSString *SpdLogWindowLevelInfo()
{
    return NSLocalizedString(@"Info", "SpdLog window: logging level");
}

NSString *SpdLogWindowLevelWarning()
{
    return NSLocalizedString(@"Warning", "SpdLog window: logging level");
}

NSString *SpdLogWindowLevelError()
{
    return NSLocalizedString(@"Error", "SpdLog window: logging level");
}

NSString *SpdLogWindowLevelCritical()
{
    return NSLocalizedString(@"Critical", "SpdLog window: logging level");
}

NSString *SpdLogWindowLevelOff()
{
    return NSLocalizedString(@"Off", "SpdLog window: logging level, turns logging off");
}

NSString *SpdLogWindowApplyLevelToAllLoggers()
{
    return NSLocalizedString(@"all", "SpdLog window: submenu applying a level to all loggers");
}

} // namespace nc::utility::localizable
