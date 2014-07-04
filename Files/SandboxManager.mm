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
    m_BookmarksDirty = false;
}

bool SandboxManager::Empty() const
{
    return m_Bookmarks.empty();
}

bool SandboxManager::AskAccessForPath(const string& _path)
{
    NSOpenPanel * openPanel = [NSOpenPanel openPanel];
    openPanel.canChooseFiles = false;
    openPanel.canChooseDirectories = true;
    openPanel.allowsMultipleSelection = false;
    openPanel.directoryURL = [[NSURL alloc] initFileURLWithPath:[NSString stringWithUTF8String:_path.c_str()]];
    long res = [openPanel runModal];
    if(res == NSModalResponseOK) {
        NSURL *url = openPanel.URL;
        
        // todo: check actual returned path
        
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
            m_Bookmarks.emplace_back(bm);
            m_BookmarksDirty = true;
            return true;
        }
    }
    return false;
}