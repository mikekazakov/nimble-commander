// Copyright (C) 2017-2019 Michael Kazakov. Subject to GNU General Public License version 3.
#include "FilenameTextControl.h"
#include <AppKit/AppKit.h>
#include <Utility/ObjCpp.h>
#include <Utility/FilenameTextNavigation.h>
#include <Utility/StringExtras.h>
#include <Utility/PathManip.h>
#include <boost/filesystem/path.hpp>

@interface NCFilenameTextStorage ()
@property (nonatomic, strong) NSMutableAttributedString *backingStore;
@property (nonatomic, strong) NSMutableDictionary *attributes;
@end

@implementation NCFilenameTextStorage

- (instancetype) init
{
    if( self = [super init] ) {
        self.backingStore = [NSMutableAttributedString new];
        self.attributes = [@{} mutableCopy];
    }
    return self;
}

- (NSString *)string
{
    return self.backingStore.string;
}

- (NSDictionary *)attributesAtIndex:(NSUInteger)location
                     effectiveRange:(NSRangePointer)range
{
    return [self.backingStore attributesAtIndex:location
                                 effectiveRange:range];
}

- (void)replaceCharactersInRange:(NSRange)range withString:(NSString *)str
{
    [self beginEditing];
    [self.backingStore replaceCharactersInRange:range withString:str];
    [self edited:NSTextStorageEditedCharacters
           range:range
  changeInLength:(NSInteger)str.length - (NSInteger)range.length];
    [self endEditing];
}

- (void)setAttributes:(NSDictionary *)attrs range:(NSRange)range
{
    [self beginEditing];
    [self.backingStore setAttributes:attrs range:range];
    [self edited:NSTextStorageEditedAttributes range:range changeInLength:0];
    [self endEditing];
}

- (NSUInteger)nextWordFromIndex:(NSUInteger)location
                        forward:(BOOL)isForward
{
    if( isForward )
        return nc::utility::FilenameTextNavigation::NavigateToNextWord(self.string, location);
    else
        return nc::utility::FilenameTextNavigation::NavigateToPreviousWord(self.string, location);
}

@end

@implementation NCFilenameTextCell
{
    NSTextView* m_FieldEditor;
    bool m_IsBuilding;
}

- (NSTextView *)fieldEditorForView:(NSView *)aControlView
{
    if( !m_FieldEditor ) {
        if( m_IsBuilding == true )
            return nil;
        m_IsBuilding = true;
        
        const auto default_fe = [aControlView.window fieldEditor:true
                                                       forObject:aControlView];
        if( !objc_cast<NSTextView>(default_fe) )
            return nil;
        
        const auto archived_fe = [NSKeyedArchiver archivedDataWithRootObject:default_fe];
        const id copied_fe = [NSKeyedUnarchiver unarchiveObjectWithData:archived_fe];
        m_FieldEditor = objc_cast<NSTextView>(copied_fe);
        [m_FieldEditor.layoutManager replaceTextStorage:[[NCFilenameTextStorage alloc] init]];
    }
    return m_FieldEditor;
}

@end

@implementation NCFilepathAutoCompletionDelegate
{
    NSMenu *m_Menu;
    NSTextView *m_TextView;
    std::shared_ptr<nc::ops::DirectoryPathAutoCompetion> m_Completion;    
}

@synthesize completion = m_Completion;

- (BOOL)control:(NSControl *)_control
       textView:(NSTextView *)_text_view
doCommandBySelector:(SEL)_command_selector
{
    assert( m_Completion );
    
    if( _command_selector != @selector(complete:) ) {
        return false;
    }
    
    const auto completions =
        m_Completion->PossibleCompletions( _text_view.string.fileSystemRepresentationSafe );
    
    if( completions.empty() ) {
        NSBeep();
        return true;
    }
    if( completions.size() == 1 ) {
        [self updateTextView:_text_view withAutocompetion:completions.front()];
        return true;
    }
    else {
        m_TextView = _text_view;
        m_Menu = [self buildMenuWithSuggestions:completions
                                 forCurrentPath:_text_view.string.fileSystemRepresentationSafe]; 
        [m_Menu popUpMenuPositioningItem:nil
                              atLocation:NSMakePoint(_control.frame.origin.x,
                                                     _control.frame.origin.y - 10)
                                  inView:_control.superview];
        return true;
    }    
}

- (NSMenu*) buildMenuWithSuggestions:(const std::vector<std::string>&)_suggestions
                      forCurrentPath:(const std::string&)_current_path
{
    std::vector<NSString *> directories;
    for( const auto &suggestion: _suggestions )
        directories.emplace_back( [NSString stringWithUTF8StdString:suggestion] );
    
    std::sort( std::begin(directories), std::end(directories), [](auto _1st, auto _2nd) {
        const auto opts = NSCaseInsensitiveSearch | NSNumericSearch |
            NSWidthInsensitiveSearch | NSForcedOrderingSearch;
        return [_1st compare:_2nd options:opts] < 0;
    });
    
    NSMenu *menu = [NSMenu new];
    static const auto icon_size = NSMakeSize(16., 16.);
    
    for( auto directory: directories ) {
        NSMenuItem *it = [NSMenuItem new];
        it.title =  directory;
        it.target = self;
        it.action = @selector(menuItemClicked:);
        it.representedObject = directory;
        
        NSImage *image = nil;
        if( self.isNativeVFS ) {
            const auto path = m_Completion->Complete(_current_path, directory.UTF8String);
            image = [NSWorkspace.sharedWorkspace iconForFile:
                     [NSString stringWithUTF8StdString:path]];
        }
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
    const auto item = objc_cast<NSMenuItem>(sender);
    if( !item )
        return;
    
    const auto directory = objc_cast<NSString>(item.representedObject);
    if( !directory )
        return;
    
    NSTextView *view = m_TextView;
    if( !view )
        return;
    
    [self updateTextView:view withAutocompetion:directory.fileSystemRepresentationSafe];
}

- (void) updateTextView:(NSTextView *)_text_view
      withAutocompetion:(const std::string&)_directory_name
{
    const auto current = std::string( _text_view.string.fileSystemRepresentationSafe );
    const auto updated = m_Completion->Complete(current, _directory_name);
    [_text_view setString:[NSString stringWithUTF8StdString:updated]];    
}

@end

namespace nc::ops {
    
DirectoryPathAutoCompletionImpl::
    DirectoryPathAutoCompletionImpl( VFSHostPtr _vfs ):
    m_VFS( std::move(_vfs) )
{        
    if( m_VFS == nullptr )
        throw std::invalid_argument("DirectoryPathAutoCompletionImpl: no vfs");
}

std::vector<std::string> DirectoryPathAutoCompletionImpl::
    PossibleCompletions( const std::string &_path )
{
    const auto directory = ExtractDirectory(_path);
    if ( const auto listing = ListingForDir(directory) ) {
        const auto filename = ExtractFilename(_path);        
        const auto indices = ListDirsWithPrefix(*listing, filename);
        
        std::vector<std::string> directories;
        for( auto index: indices )
            directories.emplace_back( listing->Filename(index) );
        
        std::sort( std::begin(directories), std::end(directories) );
        
        return directories;
    }
    return {};
}

std::string DirectoryPathAutoCompletionImpl::
    Complete( const std::string &_path, const std::string &_completion )
{ 
    boost::filesystem::path path = _path;
    
    if( path != "/" && path.has_filename() )
        path.remove_filename();
    
    path /= _completion;
    path /= "/";        
    
    return path.native();
}    
    
std::string DirectoryPathAutoCompletionImpl::ExtractDirectory( const std::string &_path ) const
{
    const boost::filesystem::path path = _path;
    if( path == "/" )
        return path.native();
    
    if( path.has_filename() )
        return path.parent_path().native();
    
    return path.native();
}
    
std::string DirectoryPathAutoCompletionImpl::ExtractFilename( const std::string &_path ) const
{
    const boost::filesystem::path path = _path;
    
    if( path.has_filename() )
        if( path.native().back() != '/' )
            return path.filename().native();
    
    return "";        
}

VFSListingPtr DirectoryPathAutoCompletionImpl::ListingForDir(const std::string& _path)
{
    if( _path.empty() )
        return nullptr;
    
    const auto path = EnsureTrailingSlash(_path);
    
    if( m_LastListing && m_LastListing->Directory() == path )
        return m_LastListing;
        
    std::shared_ptr<VFSListing> listing;
    const int rc = m_VFS->FetchDirectoryListing(path.c_str(), listing, VFSFlags::F_NoDotDot);
    if( rc == VFSError::Ok ) {
        m_LastListing = listing;
        return m_LastListing;
    }   
    return nullptr;        
}
    
std::vector<unsigned> DirectoryPathAutoCompletionImpl::
    ListDirsWithPrefix(const VFSListing& _listing, const std::string& _prefix)
{    
    std::vector<unsigned> result;
    
    const auto prefix = [NSString stringWithUTF8StdString:_prefix];
    const auto range = NSMakeRange(0, prefix.length);
    
    for( auto i: _listing ) {
        
        if( !i.IsDir() )
            continue;
        
        const auto name = i.DisplayNameNS(); 
        
        if( name.length < range.length )
            continue;
        
        const auto compare = [name compare:prefix
                                   options:NSCaseInsensitiveSearch
                                     range:range];
        
        if( compare == NSOrderedSame )
            result.emplace_back( i.Index() );
    }
    
    return result;
}    

} 
