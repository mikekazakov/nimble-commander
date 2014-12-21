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

    /**
     * Returns true if application has no access to fs but it's own container and some folders hardcoded
     */
    bool Empty() const;
    
    /**
     * Returns some (presumably the first) folder user has granted access to.
     * If Empty() then will return "".
     */
    string FirstFolderWithAccess() const;
    
    /**
     * Currently don't work with symlinks, it's a caller's duty.
     */
    bool CanAccessFolder(const string& _path) const;
    bool CanAccessFolder(const char* _path) const;
    
    /**
     * Will synchronously show NSOpenPanel.
     */
    bool AskAccessForPathSync(const string& _path, bool _mandatory_path = true);
    
    /**
     * Removes any filesystem access granted by user.
     */
    void ResetBookmarks();

private:
    struct Bookmark
    {
        NSData*data         = nil;
        NSURL *url          = nil;
        path   path         = "";
    };
    
    
    void LoadSecurityScopeBookmarks();
    void SaveSecurityScopeBookmarks();
    void StopUsingBookmarks();
    
    bool HasAccessToFolder(const path &_p) const;
    
    vector<Bookmark>        m_Bookmarks;
    mutable recursive_mutex m_Lock;
};
