// Copyright (C) 2014-2024 Michael Kazakov. Subject to GNU General Public License version 3.
#include "PreferencesWindowExternalEditorsTabNewEditorSheet.h"
#include <Utility/FileMask.h>
#include <Utility/StringExtras.h>
#include <Utility/ObjCpp.h>

@interface PreferencesWindowExternalEditorsTabNewEditorSheetStringNotEmpty : NSValueTransformer
@end
@implementation PreferencesWindowExternalEditorsTabNewEditorSheetStringNotEmpty
+ (void)initialize
{
    [NSValueTransformer setValueTransformer:[[self alloc] init] forName:NSStringFromClass(self.class)];
}
+ (Class)transformedValueClass
{
    return [NSNumber class];
}
- (id)transformedValue:(id)value
{
    if( value == nil || nc::objc_cast<NSString>(value).length == 0 )
        return [NSNumber numberWithBool:false];

    return [NSNumber numberWithBool:true];
}
@end

@implementation PreferencesWindowExternalEditorsTabNewEditorSheet

@synthesize hasTerminal;
@synthesize Info;

- (IBAction)OnClose:(id) [[maybe_unused]] _sender
{
    [self endSheet:NSModalResponseCancel];
}

- (IBAction)OnOK:(id) [[maybe_unused]] _sender
{
    if( !nc::utility::FileMask::IsWildCard(self.Info.mask.UTF8String) ) {
        auto ewc = nc::utility::FileMask::ToExtensionWildCard(self.Info.mask.UTF8String);
        if( NSString *replace = [NSString stringWithUTF8StdString:ewc] )
            self.Info.mask = replace;
    }

    [self endSheet:NSModalResponseOK];
}

- (IBAction)OnChoosePath:(id) [[maybe_unused]] _sender
{
    NSOpenPanel *panel = [NSOpenPanel openPanel];
    panel.resolvesAliases = false;
    panel.canChooseDirectories = true;
    panel.canChooseFiles = true;
    panel.allowsMultipleSelection = false;
    panel.showsHiddenFiles = true;

    if( self.Info.path.length > 0 ) {
        panel.directoryURL = [[NSURL alloc] initFileURLWithPath:self.Info.path];
    }

    if( [panel runModal] == NSModalResponseOK ) {
        if( panel.URL != nil ) {
            self.Info.path = panel.URL.path;

            if( NSString *loc_name = [NSFileManager.defaultManager displayNameAtPath:self.Info.path] )
                self.Info.name = loc_name;
        }
    }
}

@end
