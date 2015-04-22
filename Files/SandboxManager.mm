//
//  SandboxManager.cpp
//  Files
//
//  Created by Michael G. Kazakov on 04/07/14.
//  Copyright (c) 2014 Michael G. Kazakov. All rights reserved.
//

#include "SandboxManager.h"
#include "AppDelegate.h"
#include "Common.h"

static NSString *g_BookmarksKey = @"GeneralSecurityScopeBookmarks";

@interface SandboxManagerPanelDelegate : NSObject<NSOpenSavePanelDelegate>

- (instancetype) initWithPath:(const string &)_path mandatory:(bool)_mandatory;

@end

@implementation SandboxManagerPanelDelegate
{
    path m_Path;
    bool m_Mandatory;
}

- (instancetype) initWithPath:(const string &)_path mandatory:(bool)_mandatory
{
    self = [super init];
    if(self) {
        m_Mandatory = _mandatory;
        m_Path = _path;
        if(m_Path.filename() == ".")
            m_Path.remove_filename();
    }
    return self;
}

- (BOOL)panel:(id)sender shouldEnableURL:(NSURL *)_url
{
    if(!_url.fileURL)
        return false;
    if(!_url.path)
        return false;
    if(!_url.path.fileSystemRepresentation)
        return false;
    
    if(!m_Mandatory)
        return true;
    
    path p = _url.path.fileSystemRepresentation;
    if(p.filename() == ".")
        p.remove_filename();
    
    return p == m_Path;
}

@end

SandboxManager &SandboxManager::Instance()
{
    static SandboxManager *manager = nullptr;
    static once_flag once;
    call_once(once, []{
        manager = new SandboxManager;
        manager->LoadSecurityScopeBookmarks();
        [NSNotificationCenter.defaultCenter addObserverForName:NSApplicationWillTerminateNotification
                                                        object:NSApplication.sharedApplication
                                                         queue:NSOperationQueue.mainQueue
                                                    usingBlock:^(NSNotification *note) {
                                                        auto &sm = SandboxManager::Instance();
                                                        sm.StopUsingBookmarks();
                                                    }];
    });
    return *manager;
}

void SandboxManager::LoadSecurityScopeBookmarks()
{
    assert(m_Bookmarks.empty());
    
    auto bookmarks = objc_cast<NSArray>([NSUserDefaults.standardUserDefaults objectForKey:g_BookmarksKey]);
    if(!bookmarks)
        return;

    for(id obj: bookmarks)
        if( auto *data = objc_cast<NSData>(obj) ) {
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
}

bool SandboxManager::Empty() const
{
    return m_Bookmarks.empty();
}

bool SandboxManager::AskAccessForPathSync(const string& _path, bool _mandatory_path)
{
    // TODO: this stuff should work from non-main thread also.
    lock_guard<recursive_mutex> lock(m_Lock);
    
    string req_path = _path;
    
    struct stat st;
    if( lstat(req_path.c_str(), &st) == 0 && S_ISLNK(st.st_mode) ) {
        // need to resolve symlink
        char actualpath[MAXPATHLEN];
        if(realpath(req_path.c_str(), actualpath))
            req_path = actualpath;
    }
    
    NSString *dir_string = [NSString stringWithUTF8String:req_path.c_str()];
    
    // weird, but somehow NSOpenPanel refuses to go to ~/Documents directory by directoryURL(bug in OSX?)
    // so also change last dir manually
    [NSUserDefaults.standardUserDefaults setValue:dir_string forKey:@"NSNavLastRootDirectory"];

    NSOpenPanel * openPanel = NSOpenPanel.openPanel;
    openPanel.message = NSLocalizedString(@"Click ’Open’ to allow access to files contained in the selected directory",
                                          "Asking user for granting file system access for Files");
    openPanel.canChooseFiles = false;
    openPanel.canChooseDirectories = true;
    openPanel.allowsMultipleSelection = false;
    SandboxManagerPanelDelegate *delegate = [[SandboxManagerPanelDelegate alloc] initWithPath:req_path mandatory:_mandatory_path];
    openPanel.delegate = delegate;
    openPanel.directoryURL = [[NSURL alloc] initFileURLWithPath:dir_string];
    long res = [openPanel runModal];
    if(res == NSModalResponseOK)
        if(NSURL *url = openPanel.URL) {
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
                bm.path = scoped_url.path.fileSystemRepresentation;
                if(bm.path.filename() == ".") bm.path.remove_filename();
                m_Bookmarks.emplace_back(bm);
                
                SaveSecurityScopeBookmarks();
                
                return HasAccessToFolder(_path);
            }
        }
    return false;
}

bool SandboxManager::HasAccessToFolder(const path &_p) const
{
    // NB! TODO: consider using more complex comparison, regaring lowercase/uppercase and normalization stuff.
    // currently doesn't accounts this and compares directly with characters
    
    auto p = _p;
    struct stat st;
    if( lstat(p.c_str(), &st) == 0 && S_ISLNK(st.st_mode) ) {
        // need to resolve symlink
        char actualpath[MAXPATHLEN];
        if(realpath(p.c_str(), actualpath))
            p = actualpath;
    }
    
    if(p.filename() == ".") p.remove_filename();
    
    // look in our bookmarks user has given
    for(auto &i: m_Bookmarks)
        if( i.path.native().length() <= p.native().length() &&
           mismatch(i.path.native().begin(),
                    i.path.native().end(),
                    p.native().begin()).first == i.path.native().end() )
            return true;

    // look in built-in r/o access
    // also we can do stuff in dedicated temporary directory and in sandbox container
    static const vector<string> granted_ro = {
        "/bin",
        "/sbin",
        "/usr/bin",
        "/usr/lib",
        "/usr/sbin",
        "/usr/share",
        "/System",
        (path(NSTemporaryDirectory().fileSystemRepresentation).remove_filename()).native(),
        ((AppDelegate*)NSApplication.sharedApplication.delegate).startupCWD
    };
    for(auto &s: granted_ro)
        if( s.length() <= p.native().length() &&
           mismatch(s.begin(), s.end(), p.native().begin()).first == s.end())
            return true;
  
    // special treating for /Volumes dir - can browse it by default, but not dirs inside it
    if( p == "/Volumes")
        return true;
    
    return false;
}

bool SandboxManager::CanAccessFolder(const string& _path) const
{
    lock_guard<recursive_mutex> lock(m_Lock);
    return HasAccessToFolder(_path);
}

bool SandboxManager::CanAccessFolder(const char* _path) const
{
    lock_guard<recursive_mutex> lock(m_Lock);
    return _path != nullptr ? HasAccessToFolder(_path) : false;
}

string SandboxManager::FirstFolderWithAccess() const
{
    lock_guard<recursive_mutex> lock(m_Lock);
    return m_Bookmarks.empty() ? "" : m_Bookmarks.front().path.native();
}

void SandboxManager::ResetBookmarks()
{
    lock_guard<recursive_mutex> lock(m_Lock);
    
    for(auto &i: m_Bookmarks)
        [i.url stopAccessingSecurityScopedResource];
    
    m_Bookmarks.clear();
    SaveSecurityScopeBookmarks();
}

void SandboxManager::StopUsingBookmarks()
{
    lock_guard<recursive_mutex> lock(m_Lock);
    for(auto &i: m_Bookmarks)
        [i.url stopAccessingSecurityScopedResource];
}
