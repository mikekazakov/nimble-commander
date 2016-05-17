//
//  PreferencesWindowViewerTab.m
//  Files
//
//  Created by Michael G. Kazakov on 13.07.13.
//  Copyright (c) 2013 Michael G. Kazakov. All rights reserved.
//

#include <Utility/FontExtras.h>
#include "States/Viewer/BigFileViewHistory.h"
#include "Utility/Encodings.h"
#include "PreferencesWindowViewerTab.h"
#include "Config.h"

static const auto g_ConfigDefaultEncoding = "viewer.defaultEncoding";
static const auto g_ConfigModernFont      = "viewer.modern.font";
static const auto g_ConfigClassicFont     = "viewer.classic.font";

@interface PreferencesWindowViewerTab()

@property (strong) IBOutlet NSPopUpButton *DefaultEncoding;

- (IBAction) OnSetModernFont:(id)sender;
- (IBAction) OnSetClassicFont:(id)sender;
- (IBAction) DefaultEncodingChanged:(id)sender;
- (IBAction) ClearHistory:(id)sender;

@end

@implementation PreferencesWindowViewerTab
{
    NSFont *m_ModernFont;
    NSFont *m_ClassicFont;
}

- (id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil
{
    self = [super initWithNibName:NSStringFromClass(self.class) bundle:nibBundleOrNil];
    if (self) {        
    }
    
    return self;
}

- (void)loadView
{
    [super loadView];
    
    for(const auto i: encodings::LiteralEncodingsList())
        [self.DefaultEncoding addItemWithTitle: (__bridge NSString*)i.second];
    int default_encoding = encodings::EncodingFromName( GlobalConfig().GetString(g_ConfigDefaultEncoding).value_or("").c_str() );
    if(default_encoding == encodings::ENCODING_INVALID)
        default_encoding = encodings::ENCODING_MACOS_ROMAN_WESTERN; // this should not happen, but just to be sure

    for(const auto &i: encodings::LiteralEncodingsList())
        if(i.first == default_encoding) {
            [self.DefaultEncoding selectItemWithTitle:(__bridge NSString*)i.second];
            break;
        }
    
    [self.view layoutSubtreeIfNeeded];    
}

-(NSString*)identifier{
    return NSStringFromClass(self.class);
}
-(NSImage*)toolbarItemImage{
    return [NSImage imageNamed:@"PreferencesIcons_Viewer"];    
}
-(NSString*)toolbarItemLabel{
    return NSLocalizedStringFromTable(@"Viewer",
                                      @"Preferences",
                                      "General preferences tab title");
}

- (IBAction) OnSetModernFont:(id)sender
{
    m_ModernFont = [NSFont fontWithStringDescription:[NSString stringWithUTF8StdString:GlobalConfig().GetString(g_ConfigModernFont).value_or("")]];
    if(!m_ModernFont) m_ModernFont = [NSFont fontWithName: @"Menlo" size:13];
    
    NSFontManager * fontManager = [NSFontManager sharedFontManager];
    [fontManager setTarget:self];
    [fontManager setAction:@selector(ChangeModernFont:)];
    [fontManager setSelectedFont:m_ModernFont isMultiple:NO];
    [fontManager orderFrontFontPanel:self];
}

- (void)ChangeModernFont:(id)sender
{
    m_ModernFont = [sender convertFont:m_ModernFont];
    GlobalConfig().Set(g_ConfigModernFont, [m_ModernFont toStringDescription].UTF8String);
}

- (IBAction) OnSetClassicFont:(id)sender
{
    m_ModernFont = [NSFont fontWithStringDescription:[NSString stringWithUTF8StdString:GlobalConfig().GetString(g_ConfigClassicFont).value_or("")]];
    if(!m_ClassicFont) m_ClassicFont = [NSFont fontWithName: @"Menlo" size:13];
    
    NSFontManager * fontManager = [NSFontManager sharedFontManager];
    [fontManager setTarget:self];
    [fontManager setAction:@selector(ChangeClassicFont:)];
    [fontManager setSelectedFont:m_ClassicFont isMultiple:NO];
    [fontManager orderFrontFontPanel:self];
}

- (void) ChangeClassicFont:(id)sender
{
    m_ClassicFont = [sender convertFont:m_ClassicFont];
    GlobalConfig().Set(g_ConfigClassicFont, [m_ClassicFont toStringDescription].UTF8String);
}

- (void)changeAttributes:(id)sender {} // wtf, is this necessary?

- (IBAction)DefaultEncodingChanged:(id)sender
{
    for(const auto &i: encodings::LiteralEncodingsList())
        if([(__bridge NSString*)i.second isEqualToString:[[self.DefaultEncoding selectedItem] title]]) {
            GlobalConfig().Set( g_ConfigDefaultEncoding, encodings::NameFromEncoding(i.first) );
            break;
        }    
}

- (IBAction)ClearHistory:(id)sender
{
    NSAlert *alert = [[NSAlert alloc] init];
    alert.messageText = NSLocalizedStringFromTable(@"Are you sure you want to clear saved file states?",
                                                   @"Preferences",
                                                   "Message text asking if user really wants to clear saved viewer file states");
    alert.informativeText = NSLocalizedStringFromTable(@"This will erase stored positions, encodings, selections, etc.",
                                                       @"Preferences",
                                                       "Informative text displayed when the user is going to clear saved file state");
    [alert addButtonWithTitle:NSLocalizedString(@"OK","")];
    [alert addButtonWithTitle:NSLocalizedString(@"Cancel","")];
    [[alert.buttons objectAtIndex:0] setKeyEquivalent:@""];
    if([alert runModal] == NSAlertFirstButtonReturn)
        [BigFileViewHistory DeleteHistory];
}

@end
