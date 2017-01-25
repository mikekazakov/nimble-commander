#pragma once

#include <Utility/ByteCountFormatter.h>
#include "PanelViewTypes.h"

namespace panel
{
    PanelViewFilenameTrimming GetCurrentFilenamesTrimmingMode() noexcept;
    ByteCountFormatter::Type GetFileSizeFormat() noexcept;
    ByteCountFormatter::Type GetSelectionSizeFormat() noexcept;
};
