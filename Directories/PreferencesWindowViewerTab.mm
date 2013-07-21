//
//  PreferencesWindowViewerTab.m
//  Files
//
//  Created by Michael G. Kazakov on 13.07.13.
//  Copyright (c) 2013 Michael G. Kazakov. All rights reserved.
//

#import "PreferencesWindowViewerTab.h"
#import "NSUserDefaults+myColorSupport.h"
#import "Encodings.h"
#import "BigFileViewHistory.h"

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
    int default_encoding = encodings::EncodingFromName(
                                               [[[NSUserDefaults standardUserDefaults] stringForKey:@"BigFileViewDefaultEncoding"] UTF8String]);
    if(default_encoding == ENCODING_INVALID)
        default_encoding = ENCODING_MACOS_ROMAN_WESTERN; // this should not happen, but just to be sure

    for(const auto &i: encodings::LiteralEncodingsList())
        if(i.first == default_encoding)
        {
            [self.DefaultEncoding selectItemWithTitle:(__bridge NSString*)i.second];
            break;
        }
}

-(NSString*)identifier{
    return NSStringFromClass(self.class);
}
-(NSImage*)toolbarItemImage{
    return [NSImage imageNamed:NSImageNameFollowLinkFreestandingTemplate];
}
-(NSString*)toolbarItemLabel{
    return @"Internal Viewer";
}

- (IBAction) OnSetModernFont:(id)sender
{
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    m_ModernFont = [defaults fontForKey:@"BigFileViewModernFont"];
    if(!m_ModernFont) m_ModernFont = [NSFont fontWithName: @"Menlo" size:12];
    
    NSFontManager * fontManager = [NSFontManager sharedFontManager];
    [fontManager setTarget:self];
    [fontManager setAction:@selector(ChangeModernFont:)];
    [fontManager setSelectedFont:m_ModernFont isMultiple:NO];
    [fontManager orderFrontFontPanel:self];
}

- (void)ChangeModernFont:(id)sender
{
    m_ModernFont = [sender convertFont:m_ModernFont];
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    [defaults setFont:m_ModernFont forKey:@"BigFileViewModernFont"];    
}

- (IBAction) OnSetClassicFont:(id)sender
{
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    m_ClassicFont = [defaults fontForKey:@"BigFileViewClassicFont"];
    if(!m_ClassicFont) m_ClassicFont = [NSFont fontWithName: @"Menlo" size:12];
    
    NSFontManager * fontManager = [NSFontManager sharedFontManager];
    [fontManager setTarget:self];
    [fontManager setAction:@selector(ChangeClassicFont:)];
    [fontManager setSelectedFont:m_ClassicFont isMultiple:NO];
    [fontManager orderFrontFontPanel:self];
}

- (void) ChangeClassicFont:(id)sender
{
    m_ClassicFont = [sender convertFont:m_ClassicFont];
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    [defaults setFont:m_ClassicFont forKey:@"BigFileViewClassicFont"];
}

- (void)changeAttributes:(id)sender {} // wtf, is this necessary?

- (IBAction)DefaultEncodingChanged:(id)sender
{
    for(const auto &i: encodings::LiteralEncodingsList())
        if([(__bridge NSString*)i.second isEqualToString:[[self.DefaultEncoding selectedItem] title]])
        {
            NSString *encoding_name = [NSString stringWithUTF8String:encodings::NameFromEncoding(i.first)];
            [[NSUserDefaults standardUserDefaults] setObject:encoding_name forKey:@"BigFileViewDefaultEncoding"];
            break;
        }    
}

- (IBAction)ClearHistory:(id)sender
{
    NSAlert *alert = [NSAlert alertWithMessageText:@"Are you sure want to clear saved file states?"
                                     defaultButton:@"Ok"
                                   alternateButton:@"Cancel"
                                       otherButton:nil
                         informativeTextWithFormat:@"This will erase stored positions, encodings, selections etc."];
    if([alert runModal] == NSAlertDefaultReturn)
        [BigFileViewHistory DeleteHistory];
}

@end
