//
//  PanelController+DataAccess.m
//  Files
//
//  Created by Michael G. Kazakov on 22.09.13.
//  Copyright (c) 2013 Michael G. Kazakov. All rights reserved.
//

#import <Habanero/CommonPaths.h>
#import "PanelController+DataAccess.h"

@implementation PanelController (DataAccess)

- (string) currentFocusedEntryFilename
{
    if(!m_View)
        return "";
    
    if(auto item = m_View.item)
        return item.Name();
    
    return "";
}

- (string) currentFocusedEntryPath
{
    if(!m_View)
        return "";
    
    return m_Data.FullPathForEntry(m_Data.RawIndexForSortIndex(m_View.curpos));
}

- (vector<string>) selectedEntriesOrFocusedEntryFilenames
{
    if(!m_View)
        return {};
    
    if(m_Data.Stats().selected_entries_amount)
        return m_Data.SelectedEntriesFilenames();
    
    auto item = m_View.item;
    if(item && !item.IsDotDot())
        return vector<string>{ item.Name() };
    
    return {};
}

- (vector<unsigned>) selectedEntriesOrFocusedEntryIndeces
{
    vector<unsigned> inds;
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

- (vector<VFSListingItem>)selectedEntriesOrFocusedEntry
{
    vector<VFSListingItem> items;
    auto &d = self.data;
    for( auto ind: d.SortedDirectoryEntries() )
        if( d.VolatileDataAtRawPosition(ind).is_selected() )
            if( auto e = d.EntryAtRawPosition(ind) )
                if( !e.IsDotDot() )
                    items.emplace_back( move(e) );
    
    if( items.empty() )
        if( auto e = d.EntryAtSortPosition(self.view.curpos) )
            if( !e.IsDotDot() )
                items.emplace_back( move(e) );
    return items;
}

- (vector<string>) selectedEntriesOrFocusedEntryFilenamesWithDotDot
{
    if(!m_View)
        return {};
    
    if(m_Data.Stats().selected_entries_amount)
        return m_Data.SelectedEntriesFilenames();
    
    if(auto item = m_View.item)
        return vector<string>{ item.Name() };
    
    return {};
}

- (string) currentDirectoryPath
{
    return m_Data.DirectoryPathWithTrailingSlash();
}

- (const VFSHostPtr&) vfs
{
    return m_Data.Host();
}

- (string) expandPath:(const string&)_ref
{
    if( _ref.empty() )
        return {};
    
    if( _ref.front() == '/' ) // absolute path
        return _ref;
    
    if( self.vfs->IsNativeFS() &&
       _ref.front() == '~' ) { // relative to home
        auto ref = _ref.substr(1);
        path p = path(CommonPaths::Home());
        if(!ref.empty())
            p.remove_filename();
        p /= ref;
        return p.native();
    }

    // sub-dir
    path p = self.currentDirectoryPath;    
    if( _ref.find("./", 0, 2) == 0 )
        p /= _ref.substr(2);
    else
        p /= _ref;
    
    return p.native();
}

@end
