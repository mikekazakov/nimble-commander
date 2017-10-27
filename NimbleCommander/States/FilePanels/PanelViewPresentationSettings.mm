// Copyright (C) 2017 Michael Kazakov. Subject to GNU General Public License version 3.
#include <NimbleCommander/Bootstrap/Config.h>
#include "PanelViewPresentationSettings.h"

namespace nc::panel {

static const auto g_ConfigTrimmingMode = "filePanel.presentation.filenamesTrimmingMode";
PanelViewFilenameTrimming GetCurrentFilenamesTrimmingMode() noexcept
{
    static PanelViewFilenameTrimming mode = []{
        const auto v = (PanelViewFilenameTrimming)GlobalConfig().GetInt(g_ConfigTrimmingMode);
        static auto ticket = GlobalConfig().Observe(g_ConfigTrimmingMode, []{
            mode = (PanelViewFilenameTrimming)GlobalConfig().GetInt(g_ConfigTrimmingMode);
        });
        return v;
    }();
    return mode;
}

static const auto g_ConfigFileSizeFormat = "filePanel.general.fileSizeFormat";
ByteCountFormatter::Type GetFileSizeFormat() noexcept
{
    static ByteCountFormatter::Type format = []{
        const auto v = (ByteCountFormatter::Type) GlobalConfig().GetInt(g_ConfigFileSizeFormat);
        static auto ticket = GlobalConfig().Observe(g_ConfigFileSizeFormat, []{
            format = (ByteCountFormatter::Type)GlobalConfig().GetInt(g_ConfigFileSizeFormat);
        });
        return v;
    }();
    return format;
}

static const auto g_ConfigSelectionSizeFormat = "filePanel.general.selectionSizeFormat";
ByteCountFormatter::Type GetSelectionSizeFormat() noexcept
{
    static ByteCountFormatter::Type format = []{
        const auto v = (ByteCountFormatter::Type) GlobalConfig().GetInt(g_ConfigSelectionSizeFormat);
        static auto ticket = GlobalConfig().Observe(g_ConfigSelectionSizeFormat, []{
            format = (ByteCountFormatter::Type)GlobalConfig().GetInt(g_ConfigSelectionSizeFormat);
        });
        return v;
    }();
    return format;
}

}
