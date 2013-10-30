//
//  MainWindowFilePanelState.h
//  Files
//
//  Created by Michael G. Kazakov on 04.06.13.
//  Copyright (c) 2013 Michael G. Kazakov. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import <vector>
#import <string>
#import "MainWindowStateProtocol.h"
#import "FlexChainedStringsChunk.h"

@class PanelController;
@class OperationsController;
@class QuickLookView;
@class BriefSystemOverview;

@interface MainWindowFilePanelState : NSView<MainWindowStateProtocol>

@property OperationsController *OperationsController;

- (PanelController*) ActivePanelController;
- (void)ActivatePanelByController:(PanelController *)controller;

- (void)PanelPathChanged:(PanelController*)_panel;
- (void)RevealEntries:(FlexChainedStringsChunk*)_entries inPath:(const char*)_path;

- (void)GetFilePanelsGlobalPaths:(std::vector<std::string> &)_paths;


- (QuickLookView*)RequestQuickLookView:(PanelController*)_panel;
- (BriefSystemOverview*)RequestBriefSystemOverview:(PanelController*)_panel;
- (void)CloseOverlay:(PanelController*)_panel;



@end
