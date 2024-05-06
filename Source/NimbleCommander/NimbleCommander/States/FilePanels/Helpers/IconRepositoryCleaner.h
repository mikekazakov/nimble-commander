// Copyright (C) 2018-2020 Michael Kazakov. Subject to GNU General Public License version 3.
#pragma once

#include <VFSIcon/IconRepository.h>
#include <Panel/PanelData.h>

namespace nc::panel {

class IconRepositoryCleaner
{
public:
    IconRepositoryCleaner(vfsicon::IconRepository &_repository, const data::Model &_data);

    void SweepUnusedSlots();

private:
    vfsicon::IconRepository &m_Repository;
    const data::Model &m_Data;
};

} // namespace nc::panel
