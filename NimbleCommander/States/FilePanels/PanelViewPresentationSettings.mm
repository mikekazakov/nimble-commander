#include <NimbleCommander/Bootstrap/Config.h>
#include "PanelViewPresentationSettings.h"

static const auto g_ConfigTrimmingMode = "filePanel.presentation.filenamesTrimmingMode";
PanelViewFilenameTrimming panel::GetCurrentFilenamesTrimmingMode() noexcept
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
ByteCountFormatter::Type panel::GetFileSizeFormat() noexcept
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
ByteCountFormatter::Type panel::GetSelectionSizeFormat() noexcept
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
