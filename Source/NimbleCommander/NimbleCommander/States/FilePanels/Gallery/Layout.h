// Copyright (C) 2025 Michael Kazakov. Subject to GNU General Public License version 3.
#pragma once

namespace nc::panel {

struct PanelGalleryViewLayout {
    unsigned char icon_scale = 1;
    bool operator==(const PanelGalleryViewLayout &_rhs) const noexcept = default;
};

}
