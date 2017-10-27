// Copyright (C) 2014-2017 Michael Kazakov. Subject to GNU General Public License version 3.
#pragma once

/**
 * SandboxManager has tread-safe public interface.
 */
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
    
    /**
     * Will immediately return true for non-sandboxed build.
     * Otherwise, will chack access with CanAccessFolder and call AskAccessForPathSync if needed.
     */
    static bool EnsurePathAccess(const string& _path);

private:
    SandboxManager();
    
    struct Bookmark
    {
        NSData*data         = nil;
        NSURL *url          = nil;
        string path         = "";
    };
    
    
    void LoadSecurityScopeBookmarks_Unlocked();
    void SaveSecurityScopeBookmarks();
    void StopUsingBookmarks();
    
    bool HasAccessToFolder_Unlocked(const string &_p) const;
    
    vector<Bookmark>        m_Bookmarks;
    mutable spinlock        m_Lock;
};
