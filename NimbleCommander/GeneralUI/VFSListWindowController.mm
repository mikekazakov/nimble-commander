//
//  VFSListWindowController.m
//  NimbleCommander
//
//  Created by Michael G. Kazakov on 8/23/16.
//  Copyright © 2016 Michael G. Kazakov. All rights reserved.
//

#include <NimbleCommander/Core/GoogleAnalytics.h>
#include <NimbleCommander/Core/Theming/CocoaAppearanceManager.h>
#include "../Core/VFSInstanceManager.h"
#include "VFSListWindowController.h"

@interface VFSListWindowController ()
@property (strong) IBOutlet NSTableView *vfsTable;
@property (strong) IBOutlet NSSegmentedControl *listType;

@end

@implementation VFSListWindowController
{
    VFSListWindowController *m_Self;
    vector<VFSInstanceManager::ObservationTicket> m_Observations;
}

- (id) init
{
    self = [super initWithWindowNibName:NSStringFromClass(self.class)];
    if( self ) {
    }
    return self;
}

- (void)windowDidLoad
{
    [super windowDidLoad];
    CocoaAppearanceManager::Instance().ManageWindowApperance(self.window);
    
    __weak VFSListWindowController *weak_self = self;
    auto cb = [=]{
        dispatch_to_main_queue([=]{
            if( VFSListWindowController* me = weak_self )
                [me updateData];
        });
    };
    m_Observations.emplace_back( VFSInstanceManager::Instance().ObserveAliveVFSListChanged(cb));
    m_Observations.emplace_back( VFSInstanceManager::Instance().ObserveKnownVFSListChanged(cb));
    
    [self updateData];
}

- (void) show
{
    [self showWindow:self];
    m_Self = self;
    GoogleAnalytics::Instance().PostScreenView("VFS List Window");
}

- (void) updateData
{
    [self.vfsTable reloadData];
}

- (NSInteger)numberOfRowsInTableView:(NSTableView *)tableView
{
    if( self.listType.selectedSegment == 0 )
        return VFSInstanceManager::Instance().AliveHosts().size();
    else
        return VFSInstanceManager::Instance().KnownVFSCount();
}

- (nullable NSView *)tableView:(NSTableView *)tableView viewForTableColumn:(nullable NSTableColumn *)tableColumn row:(NSInteger)row
{
    VFSInstanceManager::Promise info;
    
    if( self.listType.selectedSegment == 0 ) {
        auto snapshot = VFSInstanceManager::Instance().AliveHosts();
        if( row >= 0 && row < snapshot.size() )
            info = VFSInstanceManager::Instance().PreserveVFS( snapshot.at(row) );
    }
    else {
        info = VFSInstanceManager::Instance().GetVFSPromiseByPosition((unsigned)row);
    }
    
    if( !info )
        return nil;

    if( [tableColumn.identifier isEqualToString:@"id"] ) {
        NSTextField *tf = [[NSTextField alloc] initWithFrame:NSMakeRect(0, 0, 0, 0)];
        tf.stringValue = [NSString stringWithFormat:@"%llu", info.id()];
        tf.bordered = false;
        tf.editable = false;
        tf.drawsBackground = false;
        return tf;
    }
    if( [tableColumn.identifier isEqualToString:@"type"] ) {
        NSTextField *tf = [[NSTextField alloc] initWithFrame:NSMakeRect(0, 0, 0, 0)];
        tf.stringValue = [NSString stringWithUTF8StdString:info.tag()];
        tf.bordered = false;
        tf.editable = false;
        tf.drawsBackground = false;
        return tf;
    }
    if( [tableColumn.identifier isEqualToString:@"pid"] ) {
        NSTextField *tf = [[NSTextField alloc] initWithFrame:NSMakeRect(0, 0, 0, 0)];
        if( auto parent_promise = VFSInstanceManager::Instance().GetParentPromise(info) )
            tf.stringValue = [NSString stringWithFormat:@"%llu", parent_promise.id()];
        tf.bordered = false;
        tf.editable = false;
        tf.drawsBackground = false;
        return tf;
    }
    
    if( [tableColumn.identifier isEqualToString:@"junction"] ) {
        NSTextField *tf = [[NSTextField alloc] initWithFrame:NSMakeRect(0, 0, 0, 0)];
        tf.stringValue = [NSString stringWithUTF8StdString:info.verbose_title()];
        tf.bordered = false;
        tf.editable = false;
        tf.drawsBackground = false;
        return tf;
    }

    return nil;
}

- (void)windowWillClose:(NSNotification *)notification
{
    dispatch_to_main_queue_after(10ms, [=]{
        m_Self = nil;
    });
}

- (IBAction)onTypeChanged:(id)sender
{
    [self updateData];
}

@end
