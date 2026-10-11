// Copyright (C) 2025 Michael Kazakov. Subject to GNU General Public License version 3.
#pragma once

@class NSString;

namespace nc::utility::localizable {

NSString *SpdLogWindowAutoscrollToTheBottomToolTip();
NSString *SpdLogWindowClearTheLogsToolTip();
NSString *SpdLogWindowAdjustTheLoggingSettingsToolTip();
NSString *SpdLogWindowTitle();
NSString *SpdLogWindowLevelTrace();
NSString *SpdLogWindowLevelDebug();
NSString *SpdLogWindowLevelInfo();
NSString *SpdLogWindowLevelWarning();
NSString *SpdLogWindowLevelError();
NSString *SpdLogWindowLevelCritical();
NSString *SpdLogWindowLevelOff();
NSString *SpdLogWindowApplyLevelToAllLoggers();

} // namespace nc::utility::localizable
