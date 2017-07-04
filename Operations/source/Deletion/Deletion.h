#pragma once

#include "../Operation.h"
#include "Options.h"

class VFSListingItem;

namespace nc::ops {

class DeletionJob;

class Deletion final : public Operation
{
public:
    Deletion( vector<VFSListingItem> _items, DeletionType _type );
    ~Deletion();

private:
    virtual Job *GetJob() noexcept override;
    unique_ptr<DeletionJob> m_Job;

};

}
