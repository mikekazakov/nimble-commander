//
//  MainWindowController.h
//  Directories
//
//  Created by Michael G. Kazakov on 09.02.13.
//  Copyright (c) 2013 Michael G. Kazakov. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import "FlexChainedStringsChunk.h"
#import "ApplicationSkins.h"

@class OperationsController;

@interface MainWindowController : NSWindowController <NSWindowDelegate>

// Window NIB outlets
@property (weak) IBOutlet NSBox *SheetAnchorLine;


// Window state manipulations
- (void) ResignAsWindowState:(id)_state;



- (OperationsController*) OperationsController;

// this method will be called by App in all MainWindowControllers with same params
- (void) FireDirectoryChanged: (const char*) _dir ticket:(unsigned long)_ticket;

- (void)ApplySkin:(ApplicationSkin)_skin;
- (void)OnSkinSettingsChanged;
- (void)OnApplicationWillTerminate;

- (void)RevealEntries:(FlexChainedStringsChunk*)_entries inPath:(const char*)_path;

- (void)RequestBigFileView: (const char*) _filepath;

@end
