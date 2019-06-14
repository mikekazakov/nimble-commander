// Copyright (C) 2014-2019 Michael Kazakov. Subject to GNU General Public License version 3.
#include <sys/stat.h>
#include <Habanero/algo.h>
#include <Habanero/CommonPaths.h>
#include "SandboxManager.h"
#include <NimbleCommander/Bootstrap/ActivationManager.h>
#include <boost/filesystem.hpp>
#include <Utility/ObjCpp.h>
#include <Habanero/dispatch_cpp.h>
#include <Utility/StringExtras.h>

static const auto g_BookmarksKey = @"GeneralSecurityScopeBookmarks";

@interface SandboxManagerPanelDelegate : NSObject<NSOpenSavePanelDelegate>

- (instancetype) initWithPath:(const std::string &)_path mandatory:(bool)_mandatory;

@end

@implementation SandboxManagerPanelDelegate
{
    boost::filesystem::path m_Path;
    bool m_Mandatory;
}

- (instancetype) initWithPath:(const std::string &)_path mandatory:(bool)_mandatory
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

- (BOOL)panel:(id)[[maybe_unused]]_sender shouldEnableURL:(NSURL *)_url
{
    if(!_url.fileURL)
        return false;
    if(!_url.path)
        return false;
    if(!_url.path.fileSystemRepresentation)
        return false;
    
    if(!m_Mandatory)
        return true;
    
    boost::filesystem::path p = _url.path.fileSystemRepresentation;
    if(p.filename() == ".")
        p.remove_filename();
    
    return p == m_Path;
}

@end

static std::string EnsureNoTrailingSlash( std::string _path )
{
    while( _path.length() > 1 && _path.back() == '/'  )
        _path.pop_back();
    
    return _path;
}

static std::string MakeRealPathWithoutTrailingSlash( std::string _path )
{
    // check if path is a symlink in fact
    struct stat st;
    if( lstat(_path.c_str(), &st) == 0 && S_ISLNK(st.st_mode) ) {
        // need to resolve symlink
        char actualpath[MAXPATHLEN];
        if( realpath( _path.c_str(), actualpath) )
            _path = actualpath;
    }

    // need to clear trailing slash, since here we store directories _without_ them
    return EnsureNoTrailingSlash(_path);
}

SandboxManager::SandboxManager()
{
    LoadSecurityScopeBookmarks_Unlocked();
    [NSNotificationCenter.defaultCenter addObserverForName:NSApplicationWillTerminateNotification
                                                    object:NSApplication.sharedApplication
                                                     queue:NSOperationQueue.mainQueue
                                                usingBlock:^([[maybe_unused]]NSNotification *note) {
                                                    SandboxManager::Instance().StopUsingBookmarks();
                                                }];
}

SandboxManager &SandboxManager::Instance()
{
    static auto manager = new SandboxManager;
    return *manager;
}

void SandboxManager::LoadSecurityScopeBookmarks_Unlocked()
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
    NSMutableArray *array;
    LOCK_GUARD(m_Lock) {
        array = [NSMutableArray arrayWithCapacity:m_Bookmarks.size()];
        for(auto &i: m_Bookmarks)
            [array addObject:i.data];
    }
    
    [NSUserDefaults.standardUserDefaults setObject:array.copy forKey:g_BookmarksKey];
    [NSUserDefaults.standardUserDefaults synchronize];
}

bool SandboxManager::Empty() const
{
    return m_Bookmarks.empty();
}

bool SandboxManager::AskAccessForPathSync(const std::string& _path, bool _mandatory_path)
{
    if( !dispatch_is_main_queue() ) {
        bool result = false;
        dispatch_sync( dispatch_get_main_queue(), [&] {
            result = AskAccessForPathSync(_path, _mandatory_path);
        });
        return result;
    }
    
    dispatch_assert_main_queue();
    
    const auto reqired_path = MakeRealPathWithoutTrailingSlash(_path);
    
    // weird, but somehow NSOpenPanel refuses to go to ~/Documents directory by directoryURL(bug in OSX?)
    // so also change last dir manually
    [NSUserDefaults.standardUserDefaults setValue:[NSString stringWithUTF8StdString:reqired_path]
                                           forKey:@"NSNavLastRootDirectory"];
    
    NSOpenPanel * openPanel = NSOpenPanel.openPanel;
    openPanel.message = NSLocalizedString(@"Click “Allow Access” to grant access to files in the selected directory",
                                          "Asking the user to grant filesystem access for NC");
    openPanel.prompt = NSLocalizedString(@"Allow Access",
                                         "Asking user for granting file system access for NC - button title");
    openPanel.canChooseFiles = false;
    openPanel.canChooseDirectories = true;
    openPanel.allowsMultipleSelection = false;
    SandboxManagerPanelDelegate *delegate = [[SandboxManagerPanelDelegate alloc] initWithPath:reqired_path mandatory:_mandatory_path];
    openPanel.delegate = delegate;
    openPanel.directoryURL = [NSURL fileURLWithFileSystemRepresentation:reqired_path.c_str() isDirectory:true relativeToURL:nil];
    
    const auto res = [openPanel runModal];
    if( res == NSModalResponseOK )
        if(NSURL *url = openPanel.URL) {
            NSData *bookmark_data = [url bookmarkDataWithOptions:NSURLBookmarkCreationWithSecurityScope
                                  includingResourceValuesForKeys:nil
                                                   relativeToURL:nil
                                                           error:nil];
            if( bookmark_data ) {
                NSURL *scoped_url = [NSURL URLByResolvingBookmarkData:bookmark_data
                                                              options:NSURLBookmarkResolutionWithSecurityScope
                                                        relativeToURL:nil
                                                  bookmarkDataIsStale:nil
                                                                error:nil];
                if( scoped_url &&[scoped_url startAccessingSecurityScopedResource] ) {
                    Bookmark bm;
                    bm.data = bookmark_data;
                    bm.url = scoped_url;
                    bm.path = EnsureNoTrailingSlash(scoped_url.path.fileSystemRepresentation);
                    LOCK_GUARD(m_Lock) {
                        m_Bookmarks.emplace_back(bm);
                    }
                    
                    dispatch_to_background([=]{
                        SaveSecurityScopeBookmarks();
                    });
                    
                    return HasAccessToFolder_Unlocked(_path);
                }
            }
        }
    return false;
}

bool SandboxManager::HasAccessToFolder_Unlocked(const std::string &_p) const
{
    // NB! TODO: consider using more complex comparison, regaring lowercase/uppercase and normalization stuff.
    // currently doesn't accounts this and compares directly with characters
    const auto p = MakeRealPathWithoutTrailingSlash( _p );
    
    // look in our bookmarks user has given
    for( auto &i: m_Bookmarks )
        if( has_prefix(p, i.path) )
            return true;
    
    // look in built-in r/o access
    // also we can do stuff in dedicated temporary directory and in sandbox container
    static const std::vector<std::string> granted_ro = {
        "/bin",
        "/sbin",
        "/usr/bin",
        "/usr/lib",
        "/usr/sbin",
        "/usr/share",
        "/System",
        EnsureNoTrailingSlash(NSTemporaryDirectory().fileSystemRepresentation),
        EnsureNoTrailingSlash(CommonPaths::StartupCWD())
    };
    for( auto &s: granted_ro )
        if( has_prefix(p, s) )
            return true;
  
    // special treating for /Volumes dir - can browse it by default, but not dirs inside it
    if( p == "/Volumes" )
        return true;
    
    return false;
}

bool SandboxManager::CanAccessFolder(const std::string& _path) const
{
    LOCK_GUARD(m_Lock) {
        return HasAccessToFolder_Unlocked(_path);
    }
    return false;
}

bool SandboxManager::CanAccessFolder(const char* _path) const
{
    LOCK_GUARD(m_Lock) {
        return _path != nullptr ? HasAccessToFolder_Unlocked(_path) : false;
    }
    return false;
}

std::string SandboxManager::FirstFolderWithAccess() const
{
    LOCK_GUARD(m_Lock) {
        return m_Bookmarks.empty() ? "" : m_Bookmarks.front().path;
    }
    return {};
}

void SandboxManager::ResetBookmarks()
{
    LOCK_GUARD(m_Lock) {
        for(auto &i: m_Bookmarks)
            [i.url stopAccessingSecurityScopedResource];
        m_Bookmarks.clear();
    }
    SaveSecurityScopeBookmarks();
}

void SandboxManager::StopUsingBookmarks()
{
    LOCK_GUARD(m_Lock) {
        for(auto &i: m_Bookmarks)
            [i.url stopAccessingSecurityScopedResource];
    }
}

bool SandboxManager::EnsurePathAccess(const std::string& _path)
{
    if( nc::bootstrap::ActivationManager::Instance().Sandboxed() &&
        !SandboxManager::Instance().CanAccessFolder(_path) &&
        !SandboxManager::Instance().AskAccessForPathSync(_path) )
        return false;
    return true;
}
