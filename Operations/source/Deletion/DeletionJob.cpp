#include "DeletionJob.h"
#include <Utility/PathManip.h>

namespace nc::ops {

DeletionJob::DeletionJob( vector<VFSListingItem> _items, DeletionType _type )
{
    m_SourceItems = move(_items);
    m_Type = _type;
    if( _type == DeletionType::Trash && !all_of(begin(m_SourceItems), end(m_SourceItems),
        [](auto &i) { return i.Host()->IsNativeFS(); } ) )
        throw invalid_argument("DeletionJob: invalid work mode for the provided items");
    Statistics().SetPreferredSource( Statistics::SourceType::Items );
}

DeletionJob::~DeletionJob()
{
}

void DeletionJob::Perform()
{
    DoScan();
    
    if( BlockIfPaused(); IsStopped() )
        return;

    DoDelete();
}

void DeletionJob::DoScan()
{
    for( int i = 0, e = (int)m_SourceItems.size(); i != e; ++i ) {
        const auto &item = m_SourceItems[i];
        Statistics().CommitEstimated(Statistics::SourceType::Items, 1);

        if( item.UnixType() == DT_DIR ) {
            m_Paths.push_back( EnsureTrailingSlash(item.Filename()), nullptr );
            SourceItem si;
            si.listing_item_index = i;
            si.filename = &m_Paths.back();
            m_Script.emplace(si);
            
            if( m_Type != DeletionType::Trash )
                ScanDirectory(item.Path(), i, si.filename);
        }
        else {
            m_Paths.push_back( item.Filename(), nullptr );
            SourceItem si;
            si.listing_item_index = i;
            si.filename = &m_Paths.back();
            m_Script.emplace(si);
        }
    }
}

void DeletionJob::ScanDirectory(const string &_path,
                                int _listing_item_index,
                                const chained_strings::node *_prefix)
{
    const auto &vfs = m_SourceItems[_listing_item_index].Host();

    vector<VFSDirEnt> dir_entries;
    vfs->IterateDirectoryListing(_path.c_str(), [&](const VFSDirEnt &_entry){
        dir_entries.emplace_back(_entry);
        return true;
    });
    
    for( const auto &e: dir_entries ) {
        Statistics().CommitEstimated(Statistics::SourceType::Items, 1);
        if( e.type == DT_DIR ) {
            m_Paths.push_back( EnsureTrailingSlash(e.name), _prefix );
            SourceItem si;
            si.listing_item_index = _listing_item_index;
            si.filename = &m_Paths.back();
            m_Script.emplace(si);
            
            ScanDirectory(_path + "/" + e.name, _listing_item_index, si.filename);
        }
        else {
            m_Paths.push_back( e.name, _prefix );
            SourceItem si;
            si.listing_item_index = _listing_item_index;
            si.filename = &m_Paths.back();
            m_Script.emplace(si);
        }
    }
}

void DeletionJob::DoDelete()
{
    while( !m_Script.empty() ) {
        if( BlockIfPaused(); IsStopped() )
            return;
        
        auto entry = m_Script.top();
        m_Script.pop();
        const auto path = m_SourceItems[entry.listing_item_index].Directory() +
                          entry.filename->to_str_with_pref();
        const auto &vfs = m_SourceItems[entry.listing_item_index].Host();
        if( m_Type == DeletionType::Permanent ) {
            const auto is_dir = IsPathWithTrailingSlash(path);
            if( is_dir ) {
                const auto rc = vfs->RemoveDirectory( path.c_str() );
                // TODO: process rc
            }
            else {
                const auto rc = vfs->Unlink( path.c_str() );
                // TODO: process rc
            }
        }
        else {
            const auto rc = vfs->Trash( path.c_str() );
            // TODO: process rc
        }
        Statistics().CommitProcessed(Statistics::SourceType::Items, 1);
    }
}

}
