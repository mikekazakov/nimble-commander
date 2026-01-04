// Copyright (C) 2019-2024 Michael Kazakov. Subject to GNU General Public License version 3.
#pragma once

#include <Viewer/Theme.h>
#include <NimbleCommander/Core/Theming/ThemesManager.h>

namespace nc::viewer {

class ThemeAdaptor : public Theme
{
public:
    ThemeAdaptor(ThemesManager &_themes_mgr);
    [[nodiscard]] NSFont *Font() const override;
    [[nodiscard]] NSColor *OverlayColor() const override;
    [[nodiscard]] NSColor *TextColor() const override;
    [[nodiscard]] NSColor *TextSyntaxCommentColor() const override;
    [[nodiscard]] NSColor *TextSyntaxPreprocessorColor() const override;
    [[nodiscard]] NSColor *TextSyntaxKeywordColor() const override;
    [[nodiscard]] NSColor *TextSyntaxOperatorColor() const override;
    [[nodiscard]] NSColor *TextSyntaxIdentifierColor() const override;
    [[nodiscard]] NSColor *TextSyntaxNumberColor() const override;
    [[nodiscard]] NSColor *TextSyntaxStringColor() const override;
    [[nodiscard]] NSColor *ViewerSelectionColor() const override;
    [[nodiscard]] NSColor *ViewerBackgroundColor() const override;
    void ObserveChanges(std::function<void()> _callback) override;

private:
    [[nodiscard]] const ::nc::Theme &CurrentTheme() const;
    ThemesManager &m_ThemesManager;
    ThemesManager::ObservationTicket m_ThemeObservation;
};

} // namespace nc::viewer
