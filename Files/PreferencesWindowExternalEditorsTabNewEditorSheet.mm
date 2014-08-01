//
//  PreferencesWindowExternalEditorsTabNewEditorSheet.m
//  Files
//
//  Created by Michael G. Kazakov on 07.04.14.
//  Copyright (c) 2014 Michael G. Kazakov. All rights reserved.
//

#import "PreferencesWindowExternalEditorsTabNewEditorSheet.h"

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
{
    void (^m_OnOK)();
}

- (id) init
{
    self = [super initWithWindowNibName:NSStringFromClass(self.class)];
    if(self) {
    }
    return self;
}

- (void)windowDidLoad
{
    [super windowDidLoad];
    
    // Implement this method to handle any initialization after your window controller's window has been loaded from its nib file.
}

- (bool) hasTerminal
{
    return configuration::has_terminal;
}

- (void)ShowSheet:(NSWindow *) _window
       ok_handler:(void(^)())_handler
{
    m_OnOK = _handler;
    [NSApp beginSheet:self.window
       modalForWindow:_window
        modalDelegate:self
       didEndSelector:@selector(didEndSheet:returnCode:contextInfo:)
          contextInfo:nil];
}

- (IBAction)OnClose:(id)sender
{
    [NSApp endSheet:self.window returnCode:0];
}

- (IBAction)OnOK:(id)sender
{
    m_OnOK();
    [NSApp endSheet:self.window returnCode:0];
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

- (void)didEndSheet:(NSWindow *)sheet returnCode:(NSInteger)returnCode contextInfo:(void *)contextInfo
{
    [self.window orderOut:self];
    m_OnOK = nil;
}

@end
