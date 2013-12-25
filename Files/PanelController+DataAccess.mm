//
//  PanelController+DataAccess.m
//  Files
//
//  Created by Michael G. Kazakov on 22.09.13.
//  Copyright (c) 2013 Michael G. Kazakov. All rights reserved.
//

#import "PanelController+DataAccess.h"

@implementation PanelController (DataAccess)


- (bool) GetCurrentFocusedEntryFilename:(char*) _filename
{
    assert(m_Data && m_View);
    auto const *item = [m_View CurrentItem];
    if(!item)
        return false;
    strcpy(_filename, item->Name());
    return true;
}

- (bool) GetCurrentFocusedEntryFilePathRelativeToHost:(char*) _file_path
{
    assert(m_Data && m_View);
    
    int sort_pos = [m_View GetCursorPosition];
    if(sort_pos < 0)
        return false;
    int raw_pos = m_Data->SortedDirectoryEntries()[sort_pos];
    // Handle directories.
    
    strcpy(_file_path, m_Data->FullPathForEntry(raw_pos).c_str());
    
/*    auto const &entry = m_Data->DirectoryEntries()[raw_pos];

    if(!entry.IsDotDot())
    {
        strcpy(_file_path, m_Data->DirectoryPathWithTrailingSlash().c_str());
        strcat(_file_path, entry.Name());
    }
    else
    {
        // need to cut the last slash
        m_Data->GetDirectoryPathWithTrailingSlash(_file_path);
        char *s = strrchr(_file_path, '/');
        if(s && s != _file_path) // to exclude dot-dot in root
        {
            *s = 0;
            s = strrchr(_file_path, '/');
            if(s)
                *(s+1) = 0;
        }
    }*/
    return true;
}

- (chained_strings) GetSelectedEntriesOrFocusedEntryWithoutDotDot
{
    if(m_Data->Stats().selected_entries_amount)
    {
        return m_Data->StringsFromSelectedEntries();
    }
    else
    {
        auto const *item = [m_View CurrentItem];
        if(item && !item->IsDotDot())
            return chained_strings(item->Name());
        
        return chained_strings();
    }
}

- (bool) GetCurrentDirectoryPathRelativeToHost:(char*) _path
{
//    m_Data->GetDirectoryPathWithTrailingSlash(_path);
    strcpy(_path, m_Data->DirectoryPathWithTrailingSlash().c_str());
    return true;
}

- (shared_ptr<VFSHost>) GetCurrentVFSHost
{
    return m_HostsStack.back();
}

@end
