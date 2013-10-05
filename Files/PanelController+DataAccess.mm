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
    auto const &entry = m_Data->DirectoryEntries()[raw_pos];

    if(!entry.IsDotDot())
    {
        m_Data->GetDirectoryPathWithTrailingSlash(_file_path);
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
    }
    return true;
}

- (FlexChainedStringsChunk*) GetSelectedEntriesOrFocusedEntryWithoutDotDot
{
    FlexChainedStringsChunk *files = 0;
    if(m_Data->GetSelectedItemsCount() > 0 )
    {
        files = m_Data->StringsFromSelectedEntries();
    }
    else
    {
        auto const *item = [m_View CurrentItem];
        if(item && !item->IsDotDot())
            files = FlexChainedStringsChunk::AllocateWithSingleString(item->Name());
    }
    return files;
}

@end
