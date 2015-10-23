//
//  GoToFolderSheetController.m
//  Files
//
//  Created by Michael G. Kazakov on 24.12.13.
//  Copyright (c) 2013 Michael G. Kazakov. All rights reserved.
//

#include "GoToFolderSheetController.h"
#include "Common.h"
#include "VFS.h"

static NSString *g_LastGoToKey = @"FilePanelsGeneralLastGoToFolder";

static vector<unsigned> ListDirsWithPrefix(const VFSFlexibleListing& _listing, const string& _prefix)
{
    vector<unsigned> result;
    
    NSString *prefix = [NSString stringWithUTF8StdString:_prefix];
    NSRange range = NSMakeRange(0, prefix.length);
    
    for( auto i: _listing ) {
        
        if( !i.IsDir() )
            continue;
        
        if(  i.NSDisplayName().length < range.length )
            continue;
        
        auto compare = [i.NSDisplayName() compare:prefix
                                          options:NSCaseInsensitiveSearch
                                            range:range];
        
        if( compare == 0 )
            result.emplace_back( i.Index() );
    }
    
    return result;
}

@interface GoToFolderSheetController()

// internal
@property (readonly) string currentDirectory; // return expanded value
@property (readonly) string currentFilename;

@end

@implementation GoToFolderSheetController
{
    function<void()>                m_Handler; // return VFS error code
    shared_ptr<VFSFlexibleListing>  m_LastListing;
}

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
    
    if(NSString *last = [NSUserDefaults.standardUserDefaults stringForKey:g_LastGoToKey])
        self.Text.stringValue = last;
    
    self.Text.delegate = self;
    [self controlTextDidChange:[NSNotification notificationWithName:@"" object:nil]];
}

- (void)showSheetWithParentWindow:(NSWindow *)_window handler:(function<void()>)_handler
{
    m_Handler = _handler;
    [_window beginSheet:self.window
      completionHandler:^(NSModalResponse returnCode){
          m_Handler = nullptr;
      }
     ];
}

- (IBAction)OnGo:(id)sender
{
    m_Handler();
}

- (void)tellLoadingResult:(int)_code
{
    if(_code == 0) {
        [NSUserDefaults.standardUserDefaults setValue:self.Text.stringValue forKey:g_LastGoToKey];
        [self.window.sheetParent endSheet:self.window returnCode:NSModalResponseStop];
    }
    else { // show error here
        self.Error.stringValue = VFSError::ToNSError(_code).localizedDescription;
    }
}

- (IBAction)OnCancel:(id)sender
{
    [self.window.sheetParent endSheet:self.window returnCode:NSModalResponseStop];
}

- (void)controlTextDidChange:(NSNotification *)notification
{
    self.GoButton.enabled = self.Text.stringValue.length > 0;
}

- (BOOL)control:(NSControl *)control textView:(NSTextView *)textView doCommandBySelector:(SEL)commandSelector
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

- (NSMenu*) buildMenuWithElements:(const vector<unsigned>&)_inds ofListing:(const VFSFlexibleListing&)_listing
{
    vector<NSString *> filenames;
    for(auto i:_inds)
        filenames.emplace_back( _listing.FilenameNS(i) );

    sort( begin(filenames), end(filenames), [](auto _1st, auto _2nd) {
        static auto opts = NSCaseInsensitiveSearch | NSNumericSearch | NSWidthInsensitiveSearch | NSForcedOrderingSearch;
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

- (void) updateUserInputWithAutocompetion:(const string&)_dir_name
{
    path curr = self.Text.stringValue.fileSystemRepresentationSafe;
    
    if( curr != "/" && curr.has_filename() )
        curr.remove_filename();
    
    curr /= _dir_name;
    curr /= "/";
    
    self.Text.stringValue = [NSString stringWithUTF8StdString:curr.native()];
}

- (string) currentDirectory
{
    path path = [self.panel expandPath:self.Text.stringValue.fileSystemRepresentationSafe];
    
    if( path == "/" )
        return path.native();
    
    if( path.has_filename() )
        path = path.parent_path();
    
    return path.native();
}

- (string) currentFilename
{
    path path = [self.panel expandPath:self.Text.stringValue.fileSystemRepresentationSafe];
    
    if( path.has_filename() )
        if( path.native().back() != '/' )
            return path.filename().native();
    return "";
}

// sync operation with simple caching
- (VFSFlexibleListing*) listingFromDir:(const string&)_path
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
    
    shared_ptr<VFSFlexibleListing> listing;
    int ret = vfs->FetchFlexibleListing(path.c_str(),
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
