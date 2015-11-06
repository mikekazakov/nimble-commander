#include "Job.h"

void FileDeletionOperationJobNew::Init(vector<VFSListingItem> _files, FileDeletionOperationType _type)
{
    if( (_type == FileDeletionOperationType::MoveToTrash || _type == FileDeletionOperationType::SecureDelete) &&
       !all_of(begin(_files), end(_files), [](auto &i) { return i.Host()->IsNativeFS(); } ) )
        throw invalid_argument("FileDeletionOperationJobNew::Init invalid work mode for current source items");
    
    m_OriginalItems = move(_files);
}

void FileDeletionOperationJobNew::Do()
{
    
    
}
