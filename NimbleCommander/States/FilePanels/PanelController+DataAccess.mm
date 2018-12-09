// Copyright (C) 2013-2018 Michael Kazakov. Subject to GNU General Public License version 3.
#include <Habanero/CommonPaths.h>
#include "PanelController+DataAccess.h"
#include "PanelDataItemVolatileData.h"
#include "PanelData.h"
#include "PanelView.h"
#include <VFS/VFS.h>

@implementation PanelController (DataAccess)

- (std::string) currentFocusedEntryFilename
{
    if(!self.view)
        return "";
    
    if(auto item = self.view.item)
        return item.Filename();
    
    return "";
}

- (std::string) currentFocusedEntryPath
{
    if(!self.view)
        return "";
    
    return self.data.FullPathForEntry(self.data.RawIndexForSortIndex(self.view.curpos));
}

- (std::vector<std::string>) selectedEntriesOrFocusedEntryFilenames
{
    if(!self.view)
        return {};
    
    if(self.data.Stats().selected_entries_amount)
        return self.data.SelectedEntriesFilenames();
    
    auto item = self.view.item;
    if(item && !item.IsDotDot())
        return std::vector<std::string>{ item.Filename() };
    
    return {};
}

- (std::vector<unsigned>) selectedEntriesOrFocusedEntryIndeces
{
    std::vector<unsigned> inds;
    auto &d = self.data;
    for( auto ind: d.SortedDirectoryEntries() ) {
        auto e = d.EntryAtRawPosition(ind);
        if( !e || e.IsDotDot() || d.VolatileDataAtRawPosition(ind).is_selected() )
            continue;
        inds.emplace_back(ind);
    }
    
    if( inds.empty() ) {
        if(!self.view.item ||
           self.view.item.IsDotDot() ||
           self.view.curpos < 0)
            return {};

        auto i = d.RawIndexForSortIndex(self.view.curpos);
        if(i < 0)
            return {};
        
        inds.emplace_back( i );
    }
    return inds;
}

- (std::vector<VFSListingItem>)selectedEntriesOrFocusedEntry
{
    std::vector<VFSListingItem> items;
    auto &d = self.data;
    for( auto ind: d.SortedDirectoryEntries() )
        if( d.VolatileDataAtRawPosition(ind).is_selected() )
            if( auto e = d.EntryAtRawPosition(ind) )
                    items.emplace_back( std::move(e) );
    
    if( items.empty() )
        if( auto e = d.EntryAtSortPosition(self.view.curpos) )
            if( !e.IsDotDot() )
                items.emplace_back( std::move(e) );
    return items;
}

- (std::vector<VFSListingItem>) selectedEntriesOrFocusedEntryWithDotDot
{
    std::vector<VFSListingItem> items;
    auto &d = self.data;
    for( auto ind: d.SortedDirectoryEntries() )
        if( d.VolatileDataAtRawPosition(ind).is_selected() )
            if( auto e = d.EntryAtRawPosition(ind) )
                    items.emplace_back( std::move(e) );
    
    if( items.empty() )
        if( auto e = d.EntryAtSortPosition(self.view.curpos) )
                items.emplace_back( std:: move(e) );
    return items;
}

- (std::vector<std::string>) selectedEntriesOrFocusedEntryFilenamesWithDotDot
{
    if(!self.view)
        return {};
    
    if(self.data.Stats().selected_entries_amount)
        return self.data.SelectedEntriesFilenames();
    
    if(auto item = self.view.item)
        return std::vector<std::string>{ item.Filename() };
    
    return {};
}

- (std::string) currentDirectoryPath
{
    return self.data.DirectoryPathWithTrailingSlash();
}

- (const VFSHostPtr&) vfs
{
    return self.data.Host();
}

- (std::string) expandPath:(const std::string&)_ref
{
    if( _ref.empty() )
        return {};
    
    if( _ref.front() == '/' ) // absolute path
        return _ref;
    
    if( self.vfs->IsNativeFS() &&
       _ref.front() == '~' ) { // relative to home
        auto ref = _ref.substr(1);
        auto p = boost::filesystem::path(CommonPaths::Home());
        if(!ref.empty())
            p.remove_filename();
        p /= ref;
        return p.native();
    }

    // sub-dir
    boost::filesystem::path p = self.currentDirectoryPath;
    if( p.empty() )
        return {};

    if( _ref.find("./", 0, 2) == 0 )
        p /= _ref.substr(2);
    else
        p /= _ref;
    
    return p.native();
}

@end
