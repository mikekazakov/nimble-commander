#pragma once

#include <VFSIcon/IconRepository.h>
#include "../PanelData.h"

namespace nc::panel {
    
class IconRepositoryCleaner
{
public:
    IconRepositoryCleaner(vfsicon::IconRepository &_repository,
                          const data::Model &_data); 
    
    void SweepUnusedSlots();
    
private:
    vfsicon::IconRepository &m_Repository;
    const data::Model &m_Data;
};    

    
}
