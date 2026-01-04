// Copyright (C) 2016-2024 Michael Kazakov. Subject to GNU General Public License version 3.
#pragma once

@class NSFont;

namespace nc::panel {

class PanelListViewGeometry
{
public:
    PanelListViewGeometry();
    PanelListViewGeometry(NSFont *_font, int _icon_scale, unsigned _padding);

    [[nodiscard]] short LineHeight() const { return m_LineHeight; }
    [[nodiscard]] short TextBaseLine() const { return m_TextBaseLine; }
    [[nodiscard]] short IconSize() const { return m_IconSize; }
    [[nodiscard]] static short LeftInset() { return 7; }
    [[nodiscard]] static short TopInset() { return 1; }
    [[nodiscard]] static short RightInset() { return 5; }
    [[nodiscard]] static short BottomInset() { return 1; }

    // Returns the the left offset of the filename text in its column
    [[nodiscard]] short FilenameOffsetInColumn() const noexcept;

private:
    short m_LineHeight;
    short m_TextBaseLine;
    short m_IconSize;
};

} // namespace nc::panel
