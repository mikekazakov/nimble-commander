//
//  PreferencesWindowPanelsTab.h
//  Files
//
//  Created by Michael G. Kazakov on 13.07.13.
//  Copyright (c) 2013 Michael G. Kazakov. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import "3rd_party/RHPreferences/RHPreferences/RHPreferences.h"


@interface PreferencesWindowPanelsTab : NSViewController <RHPreferencesViewControllerProtocol,
                                                            NSTableViewDataSource,
                                                            NSTableViewDelegate,
                                                            NSTextFieldDelegate>
- (IBAction)OnSetClassicFont:(id)sender;
@property (strong) IBOutlet NSTableView *classicColoringRulesTable;
@property (nonatomic) NSArray *classicColoringRules;
- (IBAction)OnAddNewClassicColoringRule:(id)sender;
- (IBAction)OnRemoveClassicColoringRule:(id)sender;

@property (strong) IBOutlet NSTableView *modernColoringRulesTable;
- (IBAction)OnAddNewModernColoringRule:(id)sender;
- (IBAction)OnRemoveModernColoringRule:(id)sender;
@property (strong) IBOutlet NSPopUpButton *fileSizeFormatCombo;
@property (strong) IBOutlet NSPopUpButton *selectionSizeFormatCombo;

@property (strong) IBOutlet NSScrollView *CommonOptionsScrollView;
@property (strong) IBOutlet NSStackView *CommonOptionsStackView;

@end
