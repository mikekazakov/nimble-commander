// Copyright (C) 2014-2017 Michael Kazakov. Subject to GNU General Public License version 3.
#include "../Core/FileMask.h"
#include "../Bootstrap/ActivationManager.h"
#include "PreferencesWindowExternalEditorsTabNewEditorSheet.h"

@interface PreferencesWindowExternalEditorsTabNewEditorSheetStringNotEmpty : NSValueTransformer
@end
@implementation PreferencesWindowExternalEditorsTabNewEditorSheetStringNotEmpty
+ (void) initialize
{
    [NSValueTransformer setValueTransformer:[[self alloc] init]
                                    forName:NSStringFromClass(self.class)];
}
+ (Class)transformedValueClass
{
	return [NSNumber class];
}
- (id)transformedValue:(id)value
{
    if(value == nil || ((NSString*)value).length == 0)
        return [NSNumber numberWithBool:false];
    
    return [NSNumber numberWithBool:true];
}
@end

@implementation PreferencesWindowExternalEditorsTabNewEditorSheet

- (bool) hasTerminal
{
    return ActivationManager::Instance().HasTerminal();
}

- (IBAction)OnClose:(id)sender
{
    [self endSheet:NSModalResponseCancel];
}

- (IBAction)OnOK:(id)sender
{
    if( !FileMask::IsWildCard(self.Info.mask.UTF8String) )
        if(NSString *replace =  [NSString stringWithUTF8StdString:FileMask::ToExtensionWildCard(self.Info.mask.UTF8String)])
            self.Info.mask = replace;
    
    [self endSheet:NSModalResponseOK];
}

- (IBAction)OnChoosePath:(id)sender
{
    NSOpenPanel *panel = [NSOpenPanel openPanel];
    panel.resolvesAliases = false;
    panel.canChooseDirectories = true;
    panel.canChooseFiles = true;
    panel.allowsMultipleSelection = false;
    panel.showsHiddenFiles = true;
    
    if(self.Info.path.length > 0)
    {
        panel.directoryURL = [[NSURL alloc] initFileURLWithPath:self.Info.path];
    }
    
    if([panel runModal] == NSFileHandlingPanelOKButton)
    {
        if(panel.URL != nil)
        {
            self.Info.path = panel.URL.path;
            
            if(NSString *loc_name = [NSFileManager.defaultManager displayNameAtPath:self.Info.path])
                self.Info.name = loc_name;
        }
    }
}

@end
