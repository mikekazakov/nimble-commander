//
//  SandboxManager.h
//  Files
//
//  Created by Michael G. Kazakov on 04/07/14.
//  Copyright (c) 2014 Michael G. Kazakov. All rights reserved.
//

#pragma once

// todo: mutex locking
class SandboxManager
{
public:
    static SandboxManager &Instance();

    bool Empty() const;
    
    
    bool AskAccessForPath(const string& _path);

private:
    struct Bookmark
    {
        NSData*data         = nil;
        NSURL *url          = nil;
        path   path         = "";
        bool   is_accessing = false;
    };
    
    
    void LoadSecurityScopeBookmarks();
    void SaveSecurityScopeBookmarks();
  
    
    vector<Bookmark>    m_Bookmarks;
    bool                m_BookmarksDirty = false;
    
};
