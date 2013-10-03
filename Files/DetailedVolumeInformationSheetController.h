//
//  DetailedVolumeInformationSheetController.h
//  Directories
//
//  Created by Michael G. Kazakov on 22.03.13.
//  Copyright (c) 2013 Michael G. Kazakov. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@interface DetailedVolumeInformationSheetController : NSWindowController

- (void)ShowSheet: (NSWindow *)_window destpath: (const char*)_path;
@property (strong) IBOutlet NSButton *OkButton;
- (IBAction)OnOK:(id)sender;
@property (strong) IBOutlet NSTextField *NameTextField;
@property (strong) IBOutlet NSTextField *MountedAtTextField;
@property (strong) IBOutlet NSTextField *DeviceTextField;
@property (strong) IBOutlet NSTextField *FormatTextField;
@property (strong) IBOutlet NSTextField *TotalBytesTextField;
@property (strong) IBOutlet NSTextField *FreeBytesTextField;
@property (strong) IBOutlet NSTextField *AvailableBytesTextField;
@property (strong) IBOutlet NSTextField *UsedBytesTextField;
@property (strong) IBOutlet NSTextField *ObjectsCountTextField;
@property (strong) IBOutlet NSTextField *FileCountTextField;
@property (strong) IBOutlet NSTextField *FoldersCountTextField;
@property (strong) IBOutlet NSTextField *MaxObjectsTextField;
@property (strong) IBOutlet NSTextField *IOBlockSizeTextField;
@property (strong) IBOutlet NSTextField *MinAllocationTextField;
@property (strong) IBOutlet NSTextField *AllocationClumpTextField;
@property (strong) IBOutlet NSTextView *AdvancedTextView;

// it's a self-owning object, so we need a retain loop to keep it alive, otherwise ARC will kill it
@property (strong)  DetailedVolumeInformationSheetController *ME;
@end
