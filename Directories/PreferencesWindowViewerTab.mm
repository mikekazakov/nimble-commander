//
//  PreferencesWindowViewerTab.m
//  Files
//
//  Created by Michael G. Kazakov on 13.07.13.
//  Copyright (c) 2013 Michael G. Kazakov. All rights reserved.
//

#import "PreferencesWindowViewerTab.h"
#import "NSUserDefaults+myColorSupport.h"

@implementation PreferencesWindowViewerTab
{
    NSFont *m_ModernFont;
    NSFont *m_ClassicFont;
}

- (id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil
{
    self = [super initWithNibName:NSStringFromClass(self.class) bundle:nibBundleOrNil];
    if (self) {
        // Initialization code here.
    }
    
    return self;
}

-(NSString*)identifier{
    return NSStringFromClass(self.class);
}
-(NSImage*)toolbarItemImage{
    return [NSImage imageNamed:NSImageNameFollowLinkFreestandingTemplate];
}
-(NSString*)toolbarItemLabel{
    return @"Viewer";
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

- (void)changeAttributes:(id)sender {}

@end
