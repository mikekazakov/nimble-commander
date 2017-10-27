// Copyright (C) 2017 Michael Kazakov. Subject to GNU General Public License version 3.
#pragma once

#include "../Job.h"
#include "Options.h"
#include <VFS/VFS.h>
#include <Habanero/chained_strings.h>

namespace nc::ops {

struct AttrsChangingJobCallbacks
{
    enum class SourceAccessErrorResolution { Stop, Skip, Retry };
    function< SourceAccessErrorResolution(int _err, const string &_path, VFSHost &_vfs) >
    m_OnSourceAccessError =
    [](int _err, const string &_path,VFSHost &_vfs){ return SourceAccessErrorResolution::Stop; };

    enum class ChmodErrorResolution { Stop, Skip, Retry };
    function< ChmodErrorResolution(int _err, const string &_path, VFSHost &_vfs) >
    m_OnChmodError =
    [](int _err, const string &_path,VFSHost &_vfs){ return ChmodErrorResolution::Stop; };

    enum class ChownErrorResolution { Stop, Skip, Retry };
    function< ChownErrorResolution(int _err, const string &_path, VFSHost &_vfs) >
    m_OnChownError =
    [](int _err, const string &_path,VFSHost &_vfs){ return ChownErrorResolution::Stop; };

    enum class FlagsErrorResolution { Stop, Skip, Retry };
    function< FlagsErrorResolution(int _err, const string &_path, VFSHost &_vfs) >
    m_OnFlagsError =
    [](int _err, const string &_path,VFSHost &_vfs){ return FlagsErrorResolution::Stop; };

    enum class TimesErrorResolution { Stop, Skip, Retry };
    function< TimesErrorResolution(int _err, const string &_path, VFSHost &_vfs) >
    m_OnTimesError =
    [](int _err, const string &_path,VFSHost &_vfs){ return TimesErrorResolution::Stop; };
};

class AttrsChangingJob : public Job, public AttrsChangingJobCallbacks
{
public:
    AttrsChangingJob( AttrsChangingCommand _command );
    ~AttrsChangingJob();

private:
    virtual void Perform() override;
    void DoScan();
    void ScanItem(unsigned _origin_item);
    void ScanItem(const string &_full_path,
                  const string &_filename,
                  unsigned _origin_item,
                  const chained_strings::node *_prefix);
    void DoChange();
    bool AlterSingleItem( const string &_path, VFSHost &_vfs, const VFSStat &_stat );
    bool ChmodSingleItem( const string &_path, VFSHost &_vfs, const VFSStat &_stat );
    bool ChownSingleItem( const string &_path, VFSHost &_vfs, const VFSStat &_stat );
    bool ChflagSingleItem( const string &_path, VFSHost &_vfs, const VFSStat &_stat );
    bool ChtimesSingleItem( const string &_path, VFSHost &_vfs, const VFSStat &_stat );

    struct Meta;
    const AttrsChangingCommand m_Command;
    optional<pair<uint16_t,uint16_t>> m_ChmodCommand;
    optional<pair<uint32_t,uint32_t>> m_ChflagCommand;
    chained_strings m_Filenames;
    vector<Meta>    m_Metas;
};

}
