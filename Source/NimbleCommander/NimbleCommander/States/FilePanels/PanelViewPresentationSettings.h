// Copyright (C) 2017 Michael Kazakov. Subject to GNU General Public License version 3.
#pragma once

#include <Utility/ByteCountFormatter.h>
#include "PanelViewTypes.h"

namespace nc::panel {

PanelViewFilenameTrimming GetCurrentFilenamesTrimmingMode() noexcept;
ByteCountFormatter::Type GetFileSizeFormat() noexcept;
ByteCountFormatter::Type GetSelectionSizeFormat() noexcept;

}
