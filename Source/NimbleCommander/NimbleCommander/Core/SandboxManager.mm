// Copyright (C) 2014-2024 Michael Kazakov. Subject to GNU General Public License version 3.
#include <sys/stat.h>
#include <Base/algo.h>
#include <Base/CommonPaths.h>
#include "SandboxManager.h"
#include <filesystem>
#include <Utility/ObjCpp.h>
#include <Base/dispatch_cpp.h>
#include <Utility/StringExtras.h>
#include <Utility/PathManip.h>

static const auto g_BookmarksKey = @"GeneralSecurityScopeBookmarks";

@interface SandboxManagerPanelDelegate : NSObject <NSOpenSavePanelDelegate>

- (instancetype)initWithPath:(const std::string &)_path mandatory:(bool)_mandatory;

@end

@implementation SandboxManagerPanelDelegate {
    std::filesystem::path m_Path;
    bool m_Mandatory;
}

- (instancetype)initWithPath:(const std::string &)_path mandatory:(bool)_mandatory
{
    self = [super init];
    if( self ) {
        m_Mandatory = _mandatory;
        m_Path = _path;
        if( m_Path.filename() == "." )
            m_Path.remove_filename();
    }
    return self;
}

- (BOOL)panel:(id) [[maybe_unused]] _sender shouldEnableURL:(NSURL *)_url
{
    if( !_url.fileURL )
        return false;
    if( !_url.path )
        return false;
    if( !_url.path.fileSystemRepresentation )
        return false;

    if( !m_Mandatory )
        return true;

    std::filesystem::path p = EnsureNoTrailingSlash(_url.path.fileSystemRepresentation);

    return p == m_Path;
}

@end

static std::string MakeRealPathWithoutTrailingSlash(std::string _path)
{
    // check if path is a symlink in fact
    struct stat st;
    if( lstat(_path.c_str(), &st) == 0 && S_ISLNK(st.st_mode) ) {
        // need to resolve symlink
        char actualpath[MAXPATHLEN];
        if( realpath(_path.c_str(), actualpath) )
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
                                                usingBlock:^([[maybe_unused]] NSNotification *note) {
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

    auto bookmarks = nc::objc_cast<NSArray>([NSUserDefaults.standardUserDefaults objectForKey:g_BookmarksKey]);
    if( !bookmarks )
        return;

    for( id obj : bookmarks )
        if( auto *const data = nc::objc_cast<NSData>(obj) ) {
            NSURL *const scoped_url = [NSURL URLByResolvingBookmarkData:data
                                                                options:NSURLBookmarkResolutionWithoutMounting |
                                                                        NSURLBookmarkResolutionWithSecurityScope
                                                          relativeToURL:nil
                                                    bookmarkDataIsStale:nil
                                                                  error:nil];
            if( scoped_url ) {
                // check that scoped_url is still valid
                if( [scoped_url startAccessingSecurityScopedResource] ) {
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
    {
        auto lock = std::lock_guard{m_Lock};
        array = [NSMutableArray arrayWithCapacity:m_Bookmarks.size()];
        for( auto &i : m_Bookmarks )
            [array addObject:i.data];
    }

    [NSUserDefaults.standardUserDefaults setObject:array.copy forKey:g_BookmarksKey];
    [NSUserDefaults.standardUserDefaults synchronize];
}

bool SandboxManager::Empty() const
{
    return m_Bookmarks.empty();
}

bool SandboxManager::AskAccessForPathSync(const std::string &_path, bool _mandatory_path)
{
    if( !nc::dispatch_is_main_queue() ) {
        bool result = false;
        dispatch_sync(dispatch_get_main_queue(), [&] { result = AskAccessForPathSync(_path, _mandatory_path); });
        return result;
    }

    dispatch_assert_main_queue();

    const auto reqired_path = MakeRealPathWithoutTrailingSlash(_path);

    // weird, but somehow NSOpenPanel refuses to go to ~/Documents directory by directoryURL(bug in
    // OSX?) so also change last dir manually
    [NSUserDefaults.standardUserDefaults setValue:[NSString stringWithUTF8StdString:reqired_path]
                                           forKey:@"NSNavLastRootDirectory"];

    NSOpenPanel *const openPanel = NSOpenPanel.openPanel;
    openPanel.message = NSLocalizedString(@"Click “Allow Access” to grant access to files in the selected directory",
                                          "Asking the user to grant filesystem access for NC");
    openPanel.prompt =
        NSLocalizedString(@"Allow Access", "Asking user for granting file system access for NC - button title");
    openPanel.canChooseFiles = false;
    openPanel.canChooseDirectories = true;
    openPanel.allowsMultipleSelection = false;
    SandboxManagerPanelDelegate *const delegate = [[SandboxManagerPanelDelegate alloc] initWithPath:reqired_path
                                                                                          mandatory:_mandatory_path];
    openPanel.delegate = delegate;
    openPanel.directoryURL = [NSURL fileURLWithFileSystemRepresentation:reqired_path.c_str()
                                                            isDirectory:true
                                                          relativeToURL:nil];

    const auto res = [openPanel runModal];
    if( res == NSModalResponseOK )
        if( NSURL *const url = openPanel.URL ) {
            NSData *const bookmark_data = [url bookmarkDataWithOptions:NSURLBookmarkCreationWithSecurityScope
                                        includingResourceValuesForKeys:nil
                                                         relativeToURL:nil
                                                                 error:nil];
            if( bookmark_data ) {
                NSURL *const scoped_url = [NSURL URLByResolvingBookmarkData:bookmark_data
                                                                    options:NSURLBookmarkResolutionWithSecurityScope
                                                              relativeToURL:nil
                                                        bookmarkDataIsStale:nil
                                                                      error:nil];
                if( scoped_url && [scoped_url startAccessingSecurityScopedResource] ) {
                    Bookmark bm;
                    bm.data = bookmark_data;
                    bm.url = scoped_url;
                    bm.path = EnsureNoTrailingSlash(scoped_url.path.fileSystemRepresentation);
                    {
                        auto lock = std::lock_guard{m_Lock};
                        m_Bookmarks.emplace_back(bm);
                    }

                    dispatch_to_background([this] { SaveSecurityScopeBookmarks(); });

                    return HasAccessToFolder_Unlocked(_path);
                }
            }
        }
    return false;
}

bool SandboxManager::HasAccessToFolder_Unlocked(const std::string &_p) const
{
    // NB! TODO: consider using more complex comparison, regaring lowercase/uppercase and
    // normalization stuff. currently doesn't accounts this and compares directly with characters
    const auto p = MakeRealPathWithoutTrailingSlash(_p);

    // look in our bookmarks user has given
    for( auto &i : m_Bookmarks )
        if( p.starts_with(i.path) )
            return true;

    // look in built-in r/o access
    // also we can do stuff in dedicated temporary directory and in sandbox container
    [[clang::no_destroy]] static const std::vector<std::string> granted_ro = {
        "/bin",
        "/sbin",
        "/usr/bin",
        "/usr/lib",
        "/usr/sbin",
        "/usr/share",
        "/System",
        EnsureNoTrailingSlash(NSTemporaryDirectory().fileSystemRepresentation),
        EnsureNoTrailingSlash(nc::base::CommonPaths::StartupCWD())};
    for( auto &s : granted_ro )
        if( p.starts_with(s) )
            return true;

    // special treating for /Volumes dir - can browse it by default, but not dirs inside it
    return p == "/Volumes";
}

bool SandboxManager::CanAccessFolder(const std::string &_path) const
{
    auto lock = std::lock_guard{m_Lock};
    return HasAccessToFolder_Unlocked(_path);
    return false;
}

bool SandboxManager::CanAccessFolder(const char *_path) const
{
    auto lock = std::lock_guard{m_Lock};
    return _path != nullptr ? HasAccessToFolder_Unlocked(_path) : false;
}

std::string SandboxManager::FirstFolderWithAccess() const
{
    auto lock = std::lock_guard{m_Lock};
    return m_Bookmarks.empty() ? "" : m_Bookmarks.front().path;
}

void SandboxManager::ResetBookmarks()
{
    {
        auto lock = std::lock_guard{m_Lock};
        for( auto &i : m_Bookmarks )
            [i.url stopAccessingSecurityScopedResource];
        m_Bookmarks.clear();
    }
    SaveSecurityScopeBookmarks();
}

void SandboxManager::StopUsingBookmarks()
{
    auto lock = std::lock_guard{m_Lock};
    for( auto &i : m_Bookmarks )
        [i.url stopAccessingSecurityScopedResource];
}

bool SandboxManager::EnsurePathAccess(const std::string &_path)
{
    return SandboxManager::Instance().CanAccessFolder(_path) || SandboxManager::Instance().AskAccessForPathSync(_path);
}
