// Copyright (C) 2013-2019 Michael Kazakov. Subject to GNU General Public License version 3.
#include "GoToFolderSheetController.h"
#include <VFS/VFS.h>
#include <NimbleCommander/Bootstrap/Config.h>
#include <NimbleCommander/Core/GoogleAnalytics.h>
#include <NimbleCommander/States/FilePanels/PanelController.h>
#include <Utility/CocoaAppearanceManager.h>
#include <Utility/StringExtras.h>
#include <Utility/ObjCpp.h>

static const auto g_StateGoToKey = "filePanel.goToSheetLastPath";

static std::vector<unsigned> ListDirsWithPrefix
    (const VFSListing& _listing, const std::string& _prefix)
{
    std::vector<unsigned> result;
    
    NSString *prefix = [NSString stringWithUTF8StdString:_prefix];
    NSRange range = NSMakeRange(0, prefix.length);
    
    for( auto i: _listing ) {
        
        if( !i.IsDir() )
            continue;
        
        if(  i.DisplayNameNS().length < range.length )
            continue;
        
        auto compare = [i.DisplayNameNS() compare:prefix
                                          options:NSCaseInsensitiveSearch
                                            range:range];
        
        if( compare == 0 )
            result.emplace_back( i.Index() );
    }
    
    return result;
}

@interface GoToFolderSheetController()

@property (nonatomic, readonly) std::string currentDirectory; // return expanded value
@property (nonatomic, readonly) std::string currentFilename;
@property (nonatomic) IBOutlet NSTextField *Text;
@property (nonatomic) IBOutlet NSTextField *Error;
@property (nonatomic) IBOutlet NSButton *GoButton;

- (IBAction)OnGo:(id)sender;
- (IBAction)OnCancel:(id)sender;

@end

@implementation GoToFolderSheetController
{
    std::function<void()>       m_Handler; // return VFS error code
    std::shared_ptr<VFSListing> m_LastListing;
    std::string                 m_RequestedPath;
}
@synthesize requestedPath = m_RequestedPath;

- (id)init
{
    self = [super initWithWindowNibName:NSStringFromClass(self.class)];
    if(self){
    }
    return self;
}

- (void)windowDidLoad
{
    [super windowDidLoad];
    nc::utility::CocoaAppearanceManager::Instance().ManageWindowApperance(self.window);
    
    if( StateConfig().Has(g_StateGoToKey) ) {
        auto path = StateConfig().GetString(g_StateGoToKey);
        self.Text.stringValue = [NSString stringWithUTF8StdString:path];
    }
    
    self.Text.delegate = self;
    [self controlTextDidChange:[NSNotification notificationWithName:@"" object:nil]];
    GA().PostScreenView("Go To Folder");
}

- (void)showSheetWithParentWindow:(NSWindow *)_window
                          handler:(std::function<void()>)_handler
{
    m_Handler = _handler;
    [_window beginSheet:self.window
      completionHandler:^([[maybe_unused]]NSModalResponse returnCode){
          m_Handler = nullptr;
      }
     ];
}

- (IBAction)OnGo:(id)[[maybe_unused]]sender
{
    m_RequestedPath = self.Text.stringValue.fileSystemRepresentationSafe;
    m_Handler();
}

- (void)tellLoadingResult:(int)_code
{
    if( _code == VFSError::Ok ) {
        StateConfig().Set( g_StateGoToKey, self.Text.stringValue.fileSystemRepresentationSafe );
        [self.window.sheetParent endSheet:self.window returnCode:NSModalResponseStop];
    }
    else { // show error here
        self.Error.stringValue = VFSError::ToNSError(_code).localizedDescription;
    }
}

- (IBAction)OnCancel:(id)[[maybe_unused]]sender
{
    [self.window.sheetParent endSheet:self.window returnCode:NSModalResponseStop];
}

- (void)controlTextDidChange:(NSNotification *)[[maybe_unused]]notification
{
    self.GoButton.enabled = self.Text.stringValue.length > 0;
}

- (BOOL)control:(NSControl*)[[maybe_unused]] control
               textView:(NSTextView*)[[maybe_unused]] textView
    doCommandBySelector:(SEL)commandSelector
{
    if(commandSelector == @selector(insertTab:)) {
        if( !self.panel.isUniform ) {
            NSBeep();
            return true;
        }
        
        auto p = self.currentDirectory;
        auto f = self.currentFilename;
        auto l = [self listingFromDir:p];
        if( !l ) {
            NSBeep();
            return true;
        }
        
        auto inds = ListDirsWithPrefix(*l, f);
        if( inds.empty() ) {
            NSBeep();
            return true;
        }
        
        if( inds.size() == 1 ) {
            [self updateUserInputWithAutocompetion:l->Filename(inds.front())];
        }
        else {
            auto menu = [self buildMenuWithElements:inds ofListing:*l];
            [menu popUpMenuPositioningItem:nil
                                atLocation:NSMakePoint(self.Text.frame.origin.x,
                                                       self.Text.frame.origin.y - 10)
                                    inView:self.window.contentView];
        }
        
        return true;
    }
    return false;
}

- (NSMenu*) buildMenuWithElements:(const std::vector<unsigned>&)_inds
                        ofListing:(const VFSListing&)_listing
{
    std::vector<NSString *> filenames;
    for(auto i:_inds)
        filenames.emplace_back( _listing.FilenameNS(i) );

    sort( begin(filenames), end(filenames), [](auto _1st, auto _2nd) {
        static auto opts = NSCaseInsensitiveSearch | NSNumericSearch |
                           NSWidthInsensitiveSearch | NSForcedOrderingSearch;
        return [_1st compare:_2nd options:opts] < 0;
    });
    
    
    NSMenu *menu = [NSMenu new];
    static const auto icon_size = NSMakeSize(NSFont.systemFontSize, NSFont.systemFontSize);
    
    for(auto i:filenames) {
        NSMenuItem *it = [NSMenuItem new];
        it.title =  i;
        it.target = self;
        it.action = @selector(menuItemClicked:);
        it.representedObject = i;
        
        NSImage *image = nil;
        if( _listing.Host()->IsNativeFS() )
            image = [NSWorkspace.sharedWorkspace iconForFile:
                     [[NSString stringWithUTF8StdString:_listing.Directory()] stringByAppendingString:i]];
        else
            image = [NSImage imageNamed:NSImageNameFolder];
        image.size = icon_size;
        it.image = image;
        
        [menu addItem:it];
    }
    
    return menu;
}

- (void)menuItemClicked:(id)sender
{
    if( auto item = objc_cast<NSMenuItem>(sender) )
        if( auto dir = objc_cast<NSString>(item.representedObject) )
            [self updateUserInputWithAutocompetion:dir.fileSystemRepresentationSafe];
}

- (void) updateUserInputWithAutocompetion:(const std::string&)_dir_name
{
    boost::filesystem::path curr = self.Text.stringValue.fileSystemRepresentationSafe;
    
    if( curr != "/" && curr.has_filename() )
        curr.remove_filename();
    
    curr /= _dir_name;
    curr /= "/";
    
    self.Text.stringValue = [NSString stringWithUTF8StdString:curr.native()];
}

- (std::string) currentDirectory
{
    boost::filesystem::path path = [self.panel expandPath:self.Text.stringValue.fileSystemRepresentationSafe];
    
    if( path == "/" )
        return path.native();
    
    if( path.has_filename() )
        path = path.parent_path();
    
    return path.native();
}

- (std::string) currentFilename
{
    boost::filesystem::path path = [self.panel expandPath:self.Text.stringValue.fileSystemRepresentationSafe];
    
    if( path.has_filename() )
        if( path.native().back() != '/' )
            return path.filename().native();
    return "";
}

// sync operation with simple caching
- (VFSListing*) listingFromDir:(const std::string&)_path
{
    if( _path.empty() )
        return nullptr;

    auto path = _path;
    if( path.back() != '/' )
        path += '/';
    
    if(m_LastListing &&
       m_LastListing->Directory() == path)
        return m_LastListing.get();
    
    if( !self.panel.isUniform )
        return nullptr;
    auto vfs = self.panel.vfs;
    
    std::shared_ptr<VFSListing> listing;
    int ret = vfs->FetchDirectoryListing(path.c_str(),
                                         listing,
                                         VFSFlags::F_NoDotDot,
                                         nullptr);
    if( ret == 0 ) {
        m_LastListing = listing;
        return m_LastListing.get();
    } else
        return nullptr;
}

@end
