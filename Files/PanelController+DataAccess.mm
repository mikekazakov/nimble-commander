//
//  PanelController+DataAccess.m
//  Files
//
//  Created by Michael G. Kazakov on 22.09.13.
//  Copyright (c) 2013 Michael G. Kazakov. All rights reserved.
//

#import "PanelController+DataAccess.h"

@implementation PanelController (DataAccess)

- (string) GetCurrentFocusedEntryFilename
{
    if(!m_View)
        return "";
    
    if(auto item = m_View.item)
        return item->Name();
    
    return "";
}

- (string) GetCurrentFocusedEntryFilePathRelativeToHost
{
    if(!m_View)
        return "";
    
    return m_Data.FullPathForEntry(m_Data.RawIndexForSortIndex(m_View.curpos));
}

- (chained_strings) GetSelectedEntriesOrFocusedEntryWithoutDotDot
{
    if(!m_View)
        return chained_strings();    
    
    if(m_Data.Stats().selected_entries_amount)
    {
        return m_Data.StringsFromSelectedEntries();
    }
    else
    {
        auto item = m_View.item;
        if(item && !item->IsDotDot())
            return chained_strings(item->Name());
        
        return chained_strings();
    }
}

- (chained_strings) GetSelectedEntriesOrFocusedEntryWithDotDot
{
    if(!m_View)
        return chained_strings();
    
    if(m_Data.Stats().selected_entries_amount)
    {
        return m_Data.StringsFromSelectedEntries();
    }
    else
    {
        if(auto item = m_View.item)
            return chained_strings(item->Name());
        
        return chained_strings();
    }
}

- (string) GetCurrentDirectoryPathRelativeToHost
{
    return m_Data.DirectoryPathWithTrailingSlash();
}

- (const shared_ptr<VFSHost>&) VFS
{
    return m_Data.Host();
}

@end
