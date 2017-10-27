// Copyright (C) 2017 Michael Kazakov. Subject to GNU General Public License version 3.
#include "AttrsChangingJob.h"
#include <Utility/PathManip.h>

namespace nc::ops {

struct AttrsChangingJob::Meta
{
    VFSStat stat;
    int origin_item;
};

static pair<uint16_t,uint16_t> PermissionsValueAndMask(const AttrsChangingCommand::Permissions &_p);
static pair<uint32_t,uint32_t> FlagsValueAndMask(const AttrsChangingCommand::Flags &_f);

AttrsChangingJob::AttrsChangingJob( AttrsChangingCommand _command ):
    m_Command( move(_command) )
{
    if( m_Command.permissions )
        m_ChmodCommand = PermissionsValueAndMask( *m_Command.permissions );
    if( m_Command.flags )
        m_ChflagCommand = FlagsValueAndMask( *m_Command.flags );
    
    Statistics().SetPreferredSource(Statistics::SourceType::Items);
}

AttrsChangingJob::~AttrsChangingJob()
{
}

void AttrsChangingJob::Perform()
{
    if(!m_Command.permissions &&
       !m_Command.ownage &&
       !m_Command.flags &&
       !m_Command.times )
        return;

    DoScan();

    if( BlockIfPaused(); IsStopped() )
        return;
    
    DoChange();
}

void AttrsChangingJob::DoScan()
{
    for( int i = 0, e = (int)m_Command.items.size(); i != e; ++i ) {
        if( BlockIfPaused(); IsStopped() )
            return;
        ScanItem(i);
    }
}

void AttrsChangingJob::ScanItem(unsigned _origin_item)
{
    const auto &item = m_Command.items[_origin_item];
    const auto path = item.Path();
    auto &vfs = *item.Host();
    VFSStat st;
    while( true ) {
        const auto stat_rc = vfs.Stat(path.c_str(), st, 0);
        if( stat_rc == VFSError::Ok )
            break;
        switch( m_OnSourceAccessError(stat_rc, path, vfs) ) {
            case SourceAccessErrorResolution::Stop: Stop(); return;
            case SourceAccessErrorResolution::Skip: return;
            case SourceAccessErrorResolution::Retry: continue;
        }
    }

    Meta m;
    m.stat = st;
    m.origin_item = _origin_item;
    m_Metas.emplace_back(m);
    m_Filenames.push_back(item.IsDir() ? EnsureTrailingSlash(item.Filename()) : item.Filename(),
                          nullptr);
    Statistics().CommitEstimated(Statistics::SourceType::Items, 1);
    
    if( m_Command.apply_to_subdirs && item.IsDir() ) {
        vector<VFSDirEnt> dir_entries;
        while( true ) {
            const auto callback = [&](const VFSDirEnt &_entry){
                dir_entries.emplace_back(_entry);
                return true;
            };
            const auto list_rc = vfs.IterateDirectoryListing(path.c_str(), callback);
            if( list_rc == VFSError::Ok )
                break;
            switch( m_OnSourceAccessError(list_rc, path, vfs) ) {
                case SourceAccessErrorResolution::Stop: Stop(); return;
                case SourceAccessErrorResolution::Skip: return;
                case SourceAccessErrorResolution::Retry: continue;
            }
        }
        
        const auto prefix = &m_Filenames.back();
        for( auto &dirent: dir_entries )
            ScanItem(path + "/" + dirent.name, dirent.name, _origin_item, prefix);
    }
}

void AttrsChangingJob::ScanItem(const string &_full_path,
                                const string &_filename,
                                unsigned _origin_item,
                                const chained_strings::node *_prefix)
{
    const auto &item = m_Command.items[_origin_item];
    auto &vfs = *item.Host();

    VFSStat st;
    while( true ) {
        const auto stat_rc = vfs.Stat(_full_path.c_str(), st, 0);
        if( stat_rc == VFSError::Ok )
            break;
        switch( m_OnSourceAccessError(stat_rc, _full_path, vfs) ) {
            case SourceAccessErrorResolution::Stop: Stop(); return;
            case SourceAccessErrorResolution::Skip: return;
            case SourceAccessErrorResolution::Retry: continue;
        }
    }

    Meta m;
    m.stat = st;
    m.origin_item = _origin_item;
    m_Metas.emplace_back(m);
    m_Filenames.push_back(S_ISDIR(st.mode) ? EnsureTrailingSlash(_filename) : _filename,
                          _prefix);
    Statistics().CommitEstimated(Statistics::SourceType::Items, 1);

    if( m_Command.apply_to_subdirs && S_ISDIR(st.mode) ) {
        vector<VFSDirEnt> dir_entries;
        while( true ) {
            const auto callback = [&](const VFSDirEnt &_entry){
                dir_entries.emplace_back(_entry);
                return true;
            };
            const auto list_rc = vfs.IterateDirectoryListing(_full_path.c_str(), callback);
            if( list_rc == VFSError::Ok )
                break;
            switch( m_OnSourceAccessError(list_rc, _full_path, vfs) ) {
                case SourceAccessErrorResolution::Stop: Stop(); return;
                case SourceAccessErrorResolution::Skip: return;
                case SourceAccessErrorResolution::Retry: continue;
            }
        }
        const auto prefix = &m_Filenames.back();
        for( auto &dirent: dir_entries )
            ScanItem(_full_path + "/" + dirent.name, dirent.name, _origin_item, prefix);
    }
}

void AttrsChangingJob::DoChange()
{
    int n = 0;
    for( auto i = begin(m_Filenames), e = end(m_Filenames); i != e; ++i, ++n ) {
        const auto &meta = m_Metas[n];
        const auto &origin_item = m_Command.items[meta.origin_item ];
        const auto path = origin_item.Directory() + (*i).to_str_with_pref();
        
        const auto success = AlterSingleItem(path, *origin_item.Host(), meta.stat);
        
        if( success )
            Statistics().CommitProcessed(Statistics::SourceType::Items, 1);
        
        if( BlockIfPaused(); IsStopped() )
            return;
    }
}

bool AttrsChangingJob::AlterSingleItem( const string &_path, VFSHost &_vfs, const VFSStat &_stat )
{
    if( m_ChmodCommand )
        if( !ChmodSingleItem(_path, _vfs, _stat) )
            return false;
    
    if( m_Command.ownage )
        if( !ChownSingleItem(_path, _vfs, _stat) )
            return false;
    
    if( m_ChflagCommand )
        if( !ChflagSingleItem(_path, _vfs, _stat) )
            return false;
    
    if( m_Command.times )
        if( !ChtimesSingleItem(_path, _vfs, _stat) )
            return false;
    
    return true;
}

bool AttrsChangingJob::ChmodSingleItem( const string &_path, VFSHost &_vfs, const VFSStat &_stat )
{
    const auto [new_mode, mask] = *m_ChmodCommand;
    const uint16_t mode = (_stat.mode & ~mask) | (new_mode & mask);
    if( mode == _stat.mode )
        return true;
    
    while( true ) {
        const auto chmod_rc = _vfs.SetPermissions(_path.c_str(), mode);
        if( chmod_rc == VFSError::Ok )
            break;
        switch( m_OnChmodError(chmod_rc, _path, _vfs) ) {
            case ChmodErrorResolution::Stop: Stop(); return false;
            case ChmodErrorResolution::Skip:
                Statistics().CommitSkipped(Statistics::SourceType::Items, 1);
                return false;
            case ChmodErrorResolution::Retry: continue;
        }
    }
    
    return true;
}

bool AttrsChangingJob::ChownSingleItem( const string &_path, VFSHost &_vfs, const VFSStat &_stat )
{
    const auto new_uid = m_Command.ownage->uid ? *m_Command.ownage->uid : _stat.uid;
    const auto new_gid = m_Command.ownage->gid ? *m_Command.ownage->gid : _stat.gid;
    if( new_uid == _stat.uid && new_gid == _stat.gid )
        return true;
    
    while( true ) {
        const auto chown_rc = _vfs.SetOwnership(_path.c_str(), new_uid, new_gid);
        if( chown_rc == VFSError::Ok )
            break;
        switch( m_OnChownError(chown_rc, _path, _vfs) ) {
            case ChownErrorResolution::Stop: Stop(); return false;
            case ChownErrorResolution::Skip:
                Statistics().CommitSkipped(Statistics::SourceType::Items, 1);
                return false;
            case ChownErrorResolution::Retry: continue;
        }
    }
    
    return true;
}

bool AttrsChangingJob::ChflagSingleItem( const string &_path, VFSHost &_vfs, const VFSStat &_stat )
{
    const auto [new_flags, mask] = *m_ChflagCommand;
    const uint32_t flags = (_stat.flags & ~mask) | (new_flags & mask);
    if( flags == _stat.flags )
        return true;
    
    while( true ) {
        const auto chflags_rc = _vfs.SetFlags(_path.c_str(), flags);
        if( chflags_rc == VFSError::Ok )
            break;
        switch( m_OnFlagsError(chflags_rc, _path, _vfs) ) {
            case FlagsErrorResolution::Stop: Stop(); return false;
            case FlagsErrorResolution::Skip:
                Statistics().CommitSkipped(Statistics::SourceType::Items, 1);
                return false;
            case FlagsErrorResolution::Retry: continue;
        }
    }

    return true;
}

bool AttrsChangingJob::ChtimesSingleItem( const string &_path, VFSHost &_vfs, const VFSStat &_stat )
{
    while( true ) {
        const auto set_times_rc = _vfs.SetTimes(_path.c_str(),
                                                m_Command.times->btime,
                                                m_Command.times->mtime,
                                                m_Command.times->ctime,
                                                m_Command.times->atime);
        if( set_times_rc == VFSError::Ok )
            break;
        switch( m_OnTimesError(set_times_rc, _path, _vfs) ) {
            case TimesErrorResolution::Stop: Stop(); return false;
            case TimesErrorResolution::Skip:
                Statistics().CommitSkipped(Statistics::SourceType::Items, 1);
                return false;
            case TimesErrorResolution::Retry: continue;
        }
    }

    return true;
}

static pair<uint16_t,uint16_t> PermissionsValueAndMask(const AttrsChangingCommand::Permissions &_p)
{
    uint16_t value = 0;
    uint16_t mask  = 0;
    const auto m = [&](const optional<bool> &_v, uint16_t _b) {
        if( _v ) {
            mask |= _b;
            if( *_v )
                value |= _b;
        }
    };
    
    m( _p.usr_r, S_IRUSR );
    m( _p.usr_w, S_IWUSR );
    m( _p.usr_x, S_IXUSR );
    m( _p.grp_r, S_IRGRP );
    m( _p.grp_w, S_IWGRP );
    m( _p.grp_x, S_IXGRP );
    m( _p.oth_r, S_IROTH );
    m( _p.oth_w, S_IWOTH );
    m( _p.oth_x, S_IXOTH );
    m( _p.suid,  S_ISUID );
    m( _p.sgid,  S_ISGID );
    m( _p.sticky,S_ISVTX );

    return {value, mask};
}

static pair<uint32_t,uint32_t> FlagsValueAndMask(const AttrsChangingCommand::Flags &_f)
{
    uint32_t value = 0;
    uint32_t mask  = 0;
    const auto m = [&](const optional<bool> &_v, uint32_t _b) {
        if( _v ) {
            mask |= _b;
            if( *_v )
                value |= _b;
        }
    };

    m( _f.u_nodump,  UF_NODUMP );
    m( _f.u_immutable, UF_IMMUTABLE );
    m( _f.u_append,  UF_APPEND );
    m( _f.u_opaque, UF_OPAQUE );
    m( _f.u_tracked, UF_TRACKED );
    m( _f.u_hidden, UF_HIDDEN );
    m( _f.u_compressed, UF_COMPRESSED );
    m( _f.s_archived, SF_ARCHIVED );
    m( _f.s_immutable, SF_IMMUTABLE );
    m( _f.s_append,  SF_APPEND );
    m( _f.s_restricted,  SF_RESTRICTED );
    m( _f.s_nounlink, SF_NOUNLINK );
    
    return {value, mask};
}

}
