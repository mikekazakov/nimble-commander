#include "AttrsChangingJob.h"
#include <Utility/PathManip.h>

namespace nc::ops {

struct AttrsChangingJob::Meta
{
    VFSStat stat;
    int origin_item;
};

static pair<uint16_t,uint16_t> PermissionsValueAndMask(const AttrsChangingCommand::Permissions &_p);

AttrsChangingJob::AttrsChangingJob( AttrsChangingCommand _command ):
    m_Command( move(_command) )
{
}

AttrsChangingJob::~AttrsChangingJob()
{
}

void AttrsChangingJob::Perform()
{
    DoScan();
    DoChange();
}

void AttrsChangingJob::DoScan()
{
    for( int i = 0, e = (int)m_Command.items.size(); i != e; ++i ) {
        ScanItem(i);
    }
}

bool AttrsChangingJob::ScanItem(unsigned _origin_item)
{
    const auto &item = m_Command.items[_origin_item];
    const auto path = item.Path();
    auto &vfs = *item.Host();
    VFSStat st;
    const auto stat_rc = vfs.Stat(path.c_str(), st, 0);
    // if...

    Meta m;
    m.stat = st;
    m.origin_item = _origin_item;
    m_Metas.emplace_back(m);
    m_Filenames.push_back(item.IsDir() ? EnsureTrailingSlash(item.Filename()) : item.Filename(),
                          nullptr);
    
    if( m_Command.apply_to_subdirs && item.IsDir() ) {
        vector<VFSDirEnt> dir_entries;
        const auto rc = vfs.IterateDirectoryListing(path.c_str(), [&](const VFSDirEnt &_entry){
            dir_entries.emplace_back(_entry);
            return true;
        });
        // if ...
        const auto prefix = &m_Filenames.back();
        for( auto &dirent: dir_entries )
            ScanItem(path + "/" + dirent.name, dirent.name, _origin_item, prefix);
    }
    
    return true;
}

bool AttrsChangingJob::ScanItem(const string &_full_path,
                                const string &_filename,
                                unsigned _origin_item,
                                const chained_strings::node *_prefix)
{
    const auto &item = m_Command.items[_origin_item];
    auto &vfs = *item.Host();

    VFSStat st;
    const auto stat_rc = vfs.Stat(_full_path.c_str(), st, 0);
    // if...

    Meta m;
    m.stat = st;
    m.origin_item = _origin_item;
    m_Metas.emplace_back(m);
    m_Filenames.push_back(S_ISDIR(st.mode) ? EnsureTrailingSlash(_filename) : _filename,
                          _prefix);
    

    if( m_Command.apply_to_subdirs && S_ISDIR(st.mode) ) {
        vector<VFSDirEnt> dir_entries;
        const auto rc = vfs.IterateDirectoryListing(_full_path.c_str(),[&](const VFSDirEnt &_entry){
            dir_entries.emplace_back(_entry);
            return true;
        });
        // if ...
        const auto prefix = &m_Filenames.back();
        for( auto &dirent: dir_entries )
            ScanItem(_full_path + "/" + dirent.name, dirent.name, _origin_item, prefix);
    }

    return true;
}


void AttrsChangingJob::DoChange()
{
    int n = 0;
    for( auto i = begin(m_Filenames), e = end(m_Filenames); i != e; ++i, ++n ) {
        const auto &meta = m_Metas[n];
        const auto &origin_item = m_Command.items[meta.origin_item ];
        const auto path = origin_item.Directory() + (*i).to_str_with_pref();
        AlterSingleItem(path, *origin_item.Host(), meta.stat);
    }
}

void AttrsChangingJob::AlterSingleItem( const string &_path, VFSHost &_vfs, const VFSStat &_stat )
{
    if( m_Command.permissions )
        ChmodSingleItem(_path, _vfs, _stat);
}


void AttrsChangingJob::ChmodSingleItem( const string &_path, VFSHost &_vfs, const VFSStat &_stat )
{
    const auto [new_mode, mask] = PermissionsValueAndMask( *m_Command.permissions );
    const uint16_t mode = (_stat.mode & ~mask) | (new_mode & mask);
    const auto chmod_rc = _vfs.ChMod(_path.c_str(), mode);
    // ...
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

}
