//
//  SandboxManager.cpp
//  Files
//
//  Created by Michael G. Kazakov on 04/07/14.
//  Copyright (c) 2014 Michael G. Kazakov. All rights reserved.
//

#include "SandboxManager.h"

static NSString *g_BookmarksKey = @"GeneralSecurityScopeBookmarks";

SandboxManager &SandboxManager::Instance()
{
    static SandboxManager *manager = nullptr;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        manager = new SandboxManager;
        manager->LoadSecurityScopeBookmarks();
        [NSNotificationCenter.defaultCenter addObserverForName:NSApplicationWillTerminateNotification
                                                        object:[NSApplication sharedApplication]
                                                         queue:NSOperationQueue.mainQueue
                                                    usingBlock:^(NSNotification *note) {
                                                        auto &sm = SandboxManager::Instance();
                                                        if(sm.m_BookmarksDirty)
                                                            sm.SaveSecurityScopeBookmarks();
                                                    }];
    });
    return *manager;
}

void SandboxManager::LoadSecurityScopeBookmarks()
{
    assert(m_Bookmarks.empty());
    
    id bookmarks_id = [NSUserDefaults.standardUserDefaults objectForKey:g_BookmarksKey];
    if(!bookmarks_id ||
       ![bookmarks_id isKindOfClass:NSArray.class])
        return;
    
    NSArray *bookmarks = (NSArray *)bookmarks_id;
    for(id obj: bookmarks)
        if(obj != nil &&
           [obj isKindOfClass:NSData.class]) {
            NSData *data = obj;
            NSURL *scoped_url = [NSURL URLByResolvingBookmarkData:data
                                                          options:NSURLBookmarkResolutionWithoutMounting|NSURLBookmarkResolutionWithSecurityScope
                                                    relativeToURL:nil
                                              bookmarkDataIsStale:nil
                                                            error:nil];
            if(scoped_url) {
                // check that scoped_url is still valid
                if([scoped_url startAccessingSecurityScopedResource]) {
                    Bookmark bm;
                    bm.data = data;
                    bm.url = scoped_url;
                    bm.is_accessing = true;
                    bm.path = scoped_url.path.fileSystemRepresentation;
                    m_Bookmarks.emplace_back(bm);
                }
            }
        }
}

void SandboxManager::SaveSecurityScopeBookmarks()
{
    NSMutableArray *array = [NSMutableArray arrayWithCapacity:m_Bookmarks.size()];
    for(auto &i: m_Bookmarks)
        [array addObject:i.data];
    
    [NSUserDefaults.standardUserDefaults setObject:array.copy forKey:g_BookmarksKey];
    [NSUserDefaults.standardUserDefaults synchronize];
    m_BookmarksDirty = false;
}

bool SandboxManager::Empty() const
{
    return m_Bookmarks.empty();
}

bool SandboxManager::AskAccessForPath(const string& _path)
{
    NSOpenPanel * openPanel = NSOpenPanel.openPanel;
    openPanel.message = @"Click 'OK' to allow access to files contained in the selected directory";
    openPanel.canChooseFiles = false;
    openPanel.canChooseDirectories = true;
    openPanel.allowsMultipleSelection = false;
    openPanel.directoryURL = [[NSURL alloc] initFileURLWithPath:[NSString stringWithUTF8String:_path.c_str()]];
    long res = [openPanel runModal];
    if(res == NSModalResponseOK) {
        NSURL *url = openPanel.URL;
        if(url) {
            path url_path = url.path.fileSystemRepresentation;
        
            NSData *bookmark_data = [url bookmarkDataWithOptions:NSURLBookmarkCreationWithSecurityScope
                                  includingResourceValuesForKeys:nil
                                                   relativeToURL:nil
                                                           error:nil];
            NSURL *scoped_url = [NSURL URLByResolvingBookmarkData:bookmark_data
                                                          options:NSURLBookmarkResolutionWithSecurityScope
                                                    relativeToURL:nil
                                              bookmarkDataIsStale:nil
                                                            error:nil];
            if([scoped_url startAccessingSecurityScopedResource]) {
                Bookmark bm;
                bm.data = bookmark_data;
                bm.url = scoped_url;
                bm.is_accessing = false;
                bm.path = scoped_url.path.fileSystemRepresentation;
                if(bm.path.filename() == ".") bm.path.remove_filename();
                m_Bookmarks.emplace_back(bm);
                m_BookmarksDirty = true;
                
                return HasAccessToFolder(_path);
            }
        }
    }
    return false;
}

bool SandboxManager::HasAccessToFolder(const path &_p) const
{
    auto p = _p;
    if(p.filename() == ".") p.remove_filename();
    
    // look in our bookmarks user has given
    for(auto &i: m_Bookmarks)
        if( i.path.native().length() <= p.native().length() &&
           i.path.native().compare(0, i.path.native().length(), p.native()) == 0)
            return true;

    // look in built-in r/o access
    static const vector<string> granted_ro = {
        "/bin",
        "/sbin",
        "/usr/bin",
        "/usr/lib",
        "/usr/sbin",
        "/usr/share",
        "/System"
    };
    for(auto &s: granted_ro)
        if( s.length() < p.native().length() &&
           s.compare(0, s.length(), p.native()) == 0)
            return true;
    
    return false;
}

bool SandboxManager::CanAccessFolder(const string& _path) const
{
    return HasAccessToFolder(_path);
}

bool SandboxManager::CanAccessFolder(const char* _path) const
{
    return _path != nullptr ? HasAccessToFolder(_path) : false;
}

string SandboxManager::FirstFolderWithAccess() const
{
    return m_Bookmarks.empty() ? "" : m_Bookmarks.front().path.native();
}
