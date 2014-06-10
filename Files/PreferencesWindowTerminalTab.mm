//
//  PreferencesWindowTerminalTab.m
//  Files
//
//  Created by Michael G. Kazakov on 10.06.14.
//  Copyright (c) 2014 Michael G. Kazakov. All rights reserved.
//

#import "PreferencesWindowTerminalTab.h"
#import "NSUserDefaults+myColorSupport.h"
#import "3rd_party/CategoriesObjC/NSUserDefaults+KeyPaths.h"

@implementation PreferencesWindowTerminalTab
{
    NSFont *m_Font;
}

- (id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil
{
    self = [super initWithNibName:NSStringFromClass(self.class) bundle:nibBundleOrNil];
    if (self) {
    }
    return self;
}


-(NSString*)identifier{
    return NSStringFromClass(self.class);
}
-(NSImage*)toolbarItemImage{
    return [NSImage imageNamed:NSImageNameInfo];
}
-(NSString*)toolbarItemLabel{
    return @"Terminal";
}

- (IBAction)OnSetFont:(id)sender
{
    m_Font = [NSUserDefaults.standardUserDefaults fontForKeyPath:@"Terminal.Font"];
    if(!m_Font) m_Font = [NSFont fontWithName:@"Menlo-Regular" size:13];
    
    NSFontManager * fontManager = [NSFontManager sharedFontManager];
    fontManager.target = self;
    fontManager.action = @selector(ChangeFont:);
    [fontManager setSelectedFont:m_Font isMultiple:NO];
    [fontManager orderFrontFontPanel:self];
}

- (void)ChangeFont:(id)sender
{
    m_Font = [sender convertFont:m_Font];
    [NSUserDefaults.standardUserDefaults setFont:m_Font forKeyPath:@"Terminal.Font"];
}

@end
