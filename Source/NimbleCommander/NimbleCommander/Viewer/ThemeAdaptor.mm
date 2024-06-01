// Copyright (C) 2019-2024 Michael Kazakov. Subject to GNU General Public License version 3.
#include "ThemeAdaptor.h"
#include <NimbleCommander/Core/Theming/Theme.h>

namespace nc::viewer {

ThemeAdaptor::ThemeAdaptor(ThemesManager &_themes_mgr) : m_ThemesManager{_themes_mgr}
{
}

NSFont *ThemeAdaptor::Font() const
{
    return CurrentTheme().ViewerFont();
}

NSColor *ThemeAdaptor::OverlayColor() const
{
    return CurrentTheme().ViewerOverlayColor();
}

NSColor *ThemeAdaptor::TextColor() const
{
    return CurrentTheme().ViewerTextColor();
}

NSColor *ThemeAdaptor::TextSyntaxCommentColor() const
{
    return CurrentTheme().ViewerTextSyntaxCommentColor();
}

NSColor *ThemeAdaptor::TextSyntaxPreprocessorColor() const
{
    return CurrentTheme().ViewerTextSyntaxPreprocessorColor();
}

NSColor *ThemeAdaptor::TextSyntaxKeywordColor() const
{
    return CurrentTheme().ViewerTextSyntaxKeywordColor();
}

NSColor *ThemeAdaptor::TextSyntaxOperatorColor() const
{
    return CurrentTheme().ViewerTextSyntaxOperatorColor();
}

NSColor *ThemeAdaptor::TextSyntaxIdentifierColor() const
{
    return CurrentTheme().ViewerTextSyntaxIdentifierColor();
}

NSColor *ThemeAdaptor::TextSyntaxNumberColor() const
{
    return CurrentTheme().ViewerTextSyntaxNumberColor();
}

NSColor *ThemeAdaptor::TextSyntaxStringColor() const
{
    return CurrentTheme().ViewerTextSyntaxStringColor();
}

NSColor *ThemeAdaptor::ViewerSelectionColor() const
{
    return CurrentTheme().ViewerSelectionColor();
}

NSColor *ThemeAdaptor::ViewerBackgroundColor() const
{
    return CurrentTheme().ViewerBackgroundColor();
}

void ThemeAdaptor::ObserveChanges(std::function<void()> _callback)
{
    const auto filter = ThemesManager::Notifications::Viewer;
    m_ThemeObservation = m_ThemesManager.ObserveChanges(filter, std::move(_callback));
}

const ::nc::Theme &ThemeAdaptor::CurrentTheme() const
{
    return m_ThemesManager.SelectedTheme();
}

} // namespace nc::viewer
