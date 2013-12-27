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
    
    if(auto item = [m_View CurrentItem])
        return item->Name();
    
    return "";
}

- (string) GetCurrentFocusedEntryFilePathRelativeToHost
{
    if(!m_Data || !m_View)
        return "";
    
    return m_Data->FullPathForEntry(m_Data->RawIndexForSortIndex([m_View GetCursorPosition]));
}

- (chained_strings) GetSelectedEntriesOrFocusedEntryWithoutDotDot
{
    if(!m_Data || !m_View)
        return chained_strings();    
    
    if(m_Data->Stats().selected_entries_amount)
    {
        return m_Data->StringsFromSelectedEntries();
    }
    else
    {
        auto item = [m_View CurrentItem];
        if(item && !item->IsDotDot())
            return chained_strings(item->Name());
        
        return chained_strings();
    }
}

- (chained_strings) GetSelectedEntriesOrFocusedEntryWithDotDot
{
    if(!m_Data || !m_View)
        return chained_strings();
    
    if(m_Data->Stats().selected_entries_amount)
    {
        return m_Data->StringsFromSelectedEntries();
    }
    else
    {
        if(auto item = [m_View CurrentItem])
            return chained_strings(item->Name());
        
        return chained_strings();
    }
}

- (string) GetCurrentDirectoryPathRelativeToHost
{
    if(!m_Data)
        return "";
    
    return m_Data->DirectoryPathWithTrailingSlash();
}

- (shared_ptr<VFSHost>) GetCurrentVFSHost
{
    if(m_HostsStack.empty())
        return shared_ptr<VFSHost>(nullptr);
    
    return m_HostsStack.back();
}

@end
