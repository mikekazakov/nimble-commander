//
//  PreferencesWindowExternalEditorsTab.m
//  Files
//
//  Created by Michael G. Kazakov on 07.04.14.
//  Copyright (c) 2014 Michael G. Kazakov. All rights reserved.
//

#import "ExternalEditorInfo.h"
#import "PreferencesWindowExternalEditorsTabNewEditorSheet.h"
#import "PreferencesWindowExternalEditorsTab.h"


@implementation PreferencesWindowExternalEditorsTab

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
    
    self.TableView.Target = self;
    self.TableView.DoubleAction = @selector(OnTableDoubleClick:);
}

-(NSString*)identifier{
    return NSStringFromClass(self.class);
}
-(NSImage*)toolbarItemImage{
    return [NSImage imageNamed:NSImageNameAdvanced];
}
-(NSString*)toolbarItemLabel{
    return @"External Editors";
}

- (NSMutableArray *) ExtEditors
{
    return ExternalEditorsList.sharedList.Editors;
}

- (void) setExtEditors:(NSMutableArray *)ExtEditors
{
    ExternalEditorsList.sharedList.Editors = ExtEditors;
}

- (IBAction)OnNewEditor:(id)sender
{
    PreferencesWindowExternalEditorsTabNewEditorSheet *sheet = [PreferencesWindowExternalEditorsTabNewEditorSheet new];
    sheet.Info = [ExternalEditorInfo new];
    [sheet ShowSheet:self.view.window
          ok_handler:^{
              [self.ExtEditorsController addObject:sheet.Info];
          }
     ];
}

- (IBAction)OnRemoveEditor:(id)sender {
}

- (void)OnTableDoubleClick:(id)table
{
    NSInteger row = [self.TableView clickedRow];
    if(row >= [self.ExtEditorsController.arrangedObjects count])
        return;
        
    ExternalEditorInfo *item = [self.ExtEditorsController.arrangedObjects objectAtIndex:row];
    PreferencesWindowExternalEditorsTabNewEditorSheet *sheet = [PreferencesWindowExternalEditorsTabNewEditorSheet new];
    sheet.Info = [item copy];
    [sheet ShowSheet:self.view.window
          ok_handler:^{
              [self.ExtEditorsController removeObjectAtArrangedObjectIndex:row];
              [self.ExtEditorsController insertObject:sheet.Info atArrangedObjectIndex:row];
          }
     ];
}

@end
