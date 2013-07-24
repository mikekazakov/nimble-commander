//
//  PreferencesWindowPanelsTab.m
//  Files
//
//  Created by Michael G. Kazakov on 13.07.13.
//  Copyright (c) 2013 Michael G. Kazakov. All rights reserved.
//

#import "PreferencesWindowPanelsTab.h"
#import "NSUserDefaults+myColorSupport.h"

@implementation PreferencesWindowPanelsTab
{
    NSFont *m_ModernFont;
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
    return [NSImage imageNamed:NSImageNameGoRightTemplate];
}
-(NSString*)toolbarItemLabel{
    return @"Panels";
}

- (IBAction)OnSetModernFont:(id)sender
{
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    m_ModernFont = [defaults fontForKey:@"FilePanelsModernFont"];
    if(!m_ModernFont) m_ModernFont = [NSFont fontWithName:@"Lucida Grande" size:13];

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
    [defaults setFont:m_ModernFont forKey:@"FilePanelsModernFont"];
}

@end
