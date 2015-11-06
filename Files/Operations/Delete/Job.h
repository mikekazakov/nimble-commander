#pragma once

#include "../../vfs/VFS.h"
#include "../../OperationJob.h"
#include "Options.h"

class FileDeletionOperationJobNew : public OperationJob
{
public:
    void Init(vector<VFSListingItem> _files, FileDeletionOperationType _type);
    
private:
    vector<VFSListingItem>      m_OriginalItems;
    

    FileDeletionOperationType   m_Type = FileDeletionOperationType::MoveToTrash;
    bool                        m_SkipAll = false;
};
