//
//  PanelController+DataAccess.m
//  Files
//
//  Created by Michael G. Kazakov on 22.09.13.
//  Copyright (c) 2013 Michael G. Kazakov. All rights reserved.
//

#import "PanelController+DataAccess.h"
#import "common_paths.h"

@implementation PanelController (DataAccess)

- (string) currentFocusedEntryFilename
{
    if(!m_View)
        return "";
    
    if(auto item = m_View.item)
        return item->Name();
    
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
    if(item && !item->IsDotDot())
        return vector<string>{ item->Name() };
    
    return {};
}

- (vector<string>) selectedEntriesOrFocusedEntryFilenamesWithDotDot
{
    if(!m_View)
        return {};
    
    if(m_Data.Stats().selected_entries_amount)
        return m_Data.SelectedEntriesFilenames();
    
    if(auto item = m_View.item)
        return vector<string>{ item->Name() };
    
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
    
    if( _ref.front() == '~' ) { // relative to home
        string r = _ref;
        r.replace(0, 1, CommonPaths::Get(CommonPaths::Home));
        return r;
    }

    // sub-dir
    return self.currentDirectoryPath + _ref;
}

@end
