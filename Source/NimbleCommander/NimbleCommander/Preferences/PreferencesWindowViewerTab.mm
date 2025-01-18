// Copyright (C) 2013-2025 Michael Kazakov. Subject to GNU General Public License version 3.
#include "PreferencesWindowViewerTab.h"
#include <Utility/FontExtras.h>
#include <Viewer/History.h>
#include "Utility/Encodings.h"
#include "../Bootstrap/Config.h"
#include <Utility/ObjCpp.h>

static const auto g_ConfigDefaultEncoding = "viewer.defaultEncoding";

@interface PreferencesBoolToNumberValueTransformer : NSValueTransformer
@end

@implementation PreferencesBoolToNumberValueTransformer
+ (Class)transformedValueClass
{
    return NSNumber.class;
}
+ (BOOL)allowsReverseTransformation
{
    return true;
}

- (id)transformedValue:(id)value
{
    if( auto n = nc::objc_cast<NSNumber>(value) )
        return [NSNumber numberWithInt:n.boolValue ? 1 : 0];
    return nil;
}

- (id)reverseTransformedValue:(id)value
{
    if( auto n = nc::objc_cast<NSNumber>(value) )
        return [NSNumber numberWithBool:n.intValue != 0];
    return nil;
}
@end

@interface PreferencesWindowViewerTab ()

@property(nonatomic) IBOutlet NSPopUpButton *DefaultEncoding;

@end

@implementation PreferencesWindowViewerTab {
    nc::viewer::History *m_History;
}
@synthesize DefaultEncoding;

- (instancetype)initWithHistory:(nc::viewer::History &)_history
{
    self = [super initWithNibName:NSStringFromClass(self.class) bundle:nil];
    if( self ) {
        m_History = &_history;
    }
    return self;
}

- (id)initWithNibName:(NSString *) [[maybe_unused]] _nibNameOrNil bundle:(NSBundle *) [[maybe_unused]] _nibBundleOrNil
{
    assert(0);
    return nil;
}

- (void)loadView
{
    [super loadView];

    for( const auto &i : nc::utility::LiteralEncodingsList() )
        [self.DefaultEncoding addItemWithTitle:(__bridge NSString *)i.second];
    nc::utility::Encoding default_encoding =
        nc::utility::EncodingFromName(GlobalConfig().GetString(g_ConfigDefaultEncoding).c_str());
    if( default_encoding == nc::utility::Encoding::ENCODING_INVALID )
        default_encoding =
            nc::utility::Encoding::ENCODING_MACOS_ROMAN_WESTERN; // this should not happen, but just to be sure

    for( const auto &i : nc::utility::LiteralEncodingsList() )
        if( i.first == default_encoding ) {
            [self.DefaultEncoding selectItemWithTitle:(__bridge NSString *)i.second];
            break;
        }

    [self.view layoutSubtreeIfNeeded];
}

- (NSToolbarItem *)toolbarItem
{
    NSToolbarItem *item = [[NSToolbarItem alloc] initWithItemIdentifier:self.identifier];
    item.image = self.toolbarItemImage;
    item.label = self.toolbarItemLabel;
    item.enabled = true;
    return item;
}

- (NSString *)identifier
{
    return NSStringFromClass(self.class);
}

- (NSImage *)toolbarItemImage
{
    return [NSImage imageNamed:@"preferences.toolbar.viewer"];
}

- (NSString *)toolbarItemLabel
{
    return NSLocalizedStringFromTable(@"Viewer", @"Preferences", "General preferences tab title");
}

- (void)changeAttributes:(id) [[maybe_unused]] _sender
{
} // wtf, is this necessary?

- (IBAction)DefaultEncodingChanged:(id) [[maybe_unused]] _sender
{
    for( const auto &i : nc::utility::LiteralEncodingsList() )
        if( [(__bridge NSString *)i.second isEqualToString:[[self.DefaultEncoding selectedItem] title]] ) {
            GlobalConfig().Set(g_ConfigDefaultEncoding, nc::utility::NameFromEncoding(i.first));
            break;
        }
}

- (IBAction)ClearHistory:(id) [[maybe_unused]] _sender
{
    NSAlert *alert = [[NSAlert alloc] init];
    alert.messageText =
        NSLocalizedStringFromTable(@"Are you sure you want to clear saved file states?",
                                   @"Preferences",
                                   "Message text asking if user really wants to clear saved viewer file states");
    alert.informativeText =
        NSLocalizedStringFromTable(@"This will erase stored positions, encodings, selections, etc.",
                                   @"Preferences",
                                   "Informative text displayed when the user is going to clear saved file state");
    [alert addButtonWithTitle:NSLocalizedString(@"OK", "")];
    [alert addButtonWithTitle:NSLocalizedString(@"Cancel", "")];
    [[alert.buttons objectAtIndex:0] setKeyEquivalent:@""];
    if( [alert runModal] == NSAlertFirstButtonReturn )
        m_History->ClearHistory();
}

@end
