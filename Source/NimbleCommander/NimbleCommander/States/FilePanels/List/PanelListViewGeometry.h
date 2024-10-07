// Copyright (C) 2016-2024 Michael Kazakov. Subject to GNU General Public License version 3.
#pragma once

@class NSFont;

namespace nc::panel {

class PanelListViewGeometry
{
public:
    PanelListViewGeometry();
    PanelListViewGeometry(NSFont *_font, int _icon_scale);

    short LineHeight() const { return m_LineHeight; }
    short TextBaseLine() const { return m_TextBaseLine; }
    short IconSize() const { return m_IconSize; }
    short LeftInset() const { return 7; }
    short TopInset() const { return 1; }
    short RightInset() const { return 5; }
    short BottomInset() const { return 1; }

    // Returns the the left offset of the filename text in its column
    short FilenameOffsetInColumn() const noexcept;

private:
    short m_LineHeight;
    short m_TextBaseLine;
    short m_IconSize;
};

} // namespace nc::panel
