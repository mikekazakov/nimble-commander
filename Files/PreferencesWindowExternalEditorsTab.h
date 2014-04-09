//
//  PreferencesWindowExternalEditorsTab.h
//  Files
//
//  Created by Michael G. Kazakov on 07.04.14.
//  Copyright (c) 2014 Michael G. Kazakov. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import "3rd_party/RHPreferences/RHPreferences/RHPreferences.h"

@interface PreferencesWindowExternalEditorsTab : NSViewController<RHPreferencesViewControllerProtocol>

@property (nonatomic) NSMutableArray *ExtEditors;
@property (strong) IBOutlet NSArrayController *ExtEditorsController;
@property (strong) IBOutlet NSTableView *TableView;

- (IBAction)OnNewEditor:(id)sender;
- (IBAction)OnRemoveEditor:(id)sender;


@end
