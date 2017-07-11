#pragma once

#include "../Job.h"
#include "Options.h"
#include <VFS/VFS.h>
#include <Habanero/chained_strings.h>

namespace nc::ops {

class AttrsChangingJob : public Job
{
public:
    AttrsChangingJob( AttrsChangingCommand _command );
    ~AttrsChangingJob();

private:
    virtual void Perform() override;
    void DoScan();
    bool ScanItem(unsigned _origin_item);
    bool ScanItem(const string &_full_path,
                  const string &_filename,
                  unsigned _origin_item,
                  const chained_strings::node *_prefix);
    void DoChange();
    void AlterSingleItem( const string &_path, VFSHost &_vfs, const VFSStat &_stat );
    void ChmodSingleItem( const string &_path, VFSHost &_vfs, const VFSStat &_stat );

    struct Meta;
    const AttrsChangingCommand m_Command;
    chained_strings m_Filenames;
    vector<Meta>    m_Metas;
};

}
