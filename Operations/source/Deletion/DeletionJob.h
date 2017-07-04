#pragma once

#include "../Job.h"
#include "Options.h"
#include <VFS/VFS.h>
#include <Habanero/chained_strings.h>
#include <stack>

namespace nc::ops {

class DeletionJob : public Job
{
public:
    DeletionJob( vector<VFSListingItem> _items, DeletionType _type );
    ~DeletionJob();
    
private:
    virtual void Perform() override;
    void DoScan();
    void DoDelete();
    void ScanDirectory(const string &_path,
                       int _listing_item_index,
                       const chained_strings::node *_prefix);
    vector<VFSListingItem> m_SourceItems;
    DeletionType m_Type;
    
    chained_strings m_Paths;
    struct SourceItem
    {
        int listing_item_index;
        const chained_strings::node *filename;
    };
    stack<SourceItem> m_Script;
};




}
