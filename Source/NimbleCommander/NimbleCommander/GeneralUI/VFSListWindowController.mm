// Copyright (C) 2016-2024 Michael Kazakov. Subject to GNU General Public License version 3.
#include "VFSListWindowController.h"
#include "../Core/VFSInstanceManager.h"
#include "../Core/VFSInstancePromise.h"
#include <Base/dispatch_cpp.h>
#include <Utility/StringExtras.h>

using namespace std::literals;

@interface VFSListWindowController ()
@property(nonatomic) IBOutlet NSTableView *vfsTable;
@property(nonatomic) IBOutlet NSSegmentedControl *listType;

@end

@implementation VFSListWindowController {
    VFSListWindowController *m_Self;
    std::vector<nc::core::VFSInstanceManager::ObservationTicket> m_Observations;
    nc::core::VFSInstanceManager *m_Manager;
}
@synthesize vfsTable;
@synthesize listType;

- (instancetype)initWithVFSManager:(nc::core::VFSInstanceManager &)_manager
{
    self = [super initWithWindowNibName:NSStringFromClass(self.class)];
    if( self ) {
        m_Manager = &_manager;
    }
    return self;
}

- (void)windowDidLoad
{
    [super windowDidLoad];

    __weak VFSListWindowController *weak_self = self;
    auto cb = [=] {
        dispatch_to_main_queue([=] {
            if( VFSListWindowController *const me = weak_self )
                [me updateData];
        });
    };
    m_Observations.emplace_back(m_Manager->ObserveAliveVFSListChanged(cb));
    m_Observations.emplace_back(m_Manager->ObserveKnownVFSListChanged(cb));

    [self updateData];
}

- (void)show
{
    [self showWindow:self];
    m_Self = self;
}

- (void)updateData
{
    [self.vfsTable reloadData];
}

- (NSInteger)numberOfRowsInTableView:(NSTableView *) [[maybe_unused]] tableView
{
    if( self.listType.selectedSegment == 0 )
        return m_Manager->AliveHosts().size();
    else
        return m_Manager->KnownVFSCount();
}

- (nullable NSView *)tableView:(NSTableView *) [[maybe_unused]] tableView
            viewForTableColumn:(nullable NSTableColumn *)tableColumn
                           row:(NSInteger)row
{
    nc::core::VFSInstanceManager::Promise info;

    if( self.listType.selectedSegment == 0 ) {
        auto snapshot = m_Manager->AliveHosts();
        if( row >= 0 && row < static_cast<int>(snapshot.size()) )
            info = m_Manager->PreserveVFS(snapshot.at(row));
    }
    else {
        info = m_Manager->GetVFSPromiseByPosition(static_cast<unsigned>(row));
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
        if( auto parent_promise = m_Manager->GetParentPromise(info) )
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

- (void)windowWillClose:(NSNotification *) [[maybe_unused]] _notification
{
    dispatch_to_main_queue_after(10ms, [=] { m_Self = nil; });
}

- (IBAction)onTypeChanged:(id) [[maybe_unused]] _sender
{
    [self updateData];
}

@end
