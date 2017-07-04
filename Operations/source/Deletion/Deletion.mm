#include "Deletion.h"
#include "DeletionJob.h"
#include "../Internal.h"

namespace nc::ops {

static NSString *Caption(const vector<VFSListingItem> &_files);

Deletion::Deletion( vector<VFSListingItem> _items, DeletionType _type )
{
    SetTitle(Caption(_items).UTF8String);
    
    m_Job.reset( new DeletionJob(move(_items), _type) );
}

Deletion::~Deletion()
{
}

Job *Deletion::GetJob() noexcept
{
    return m_Job.get();
}

static NSString *Caption(const vector<VFSListingItem> &_files)
{
    if( _files.size() == 1 )
        return  [NSString localizedStringWithFormat:
                 NSLocalizedStringFromTableInBundle(@"Deleting \u201c%@\u201d",
                                                    @"Localizable.strings",
                                                    Bundle(),
                                                    "Operation title for single item deletion"),
                 _files.front().NSDisplayName()];
    else
        return [NSString localizedStringWithFormat:
                NSLocalizedStringFromTableInBundle(@"Deleting %@ items",
                                                   @"Localizable.strings",
                                                   Bundle(),
                                                   "Operation title for multiple items deletion"),
                [NSNumber numberWithUnsignedLong:_files.size()]];
}

}
