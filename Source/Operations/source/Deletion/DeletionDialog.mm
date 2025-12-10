// Copyright (C) 2017-2025 Michael Kazakov. Subject to GNU General Public License version 3.
#include "DeletionDialog.h"
#include <Operations/Localizable.h>
#include "../Internal.h"
#include <VFS/VFS.h>

@interface NCOpsDeletionDialog ()

@property(strong, nonatomic) IBOutlet NSTextField *Label;
@property(strong, nonatomic) IBOutlet NSButton *primaryActionButton;
@property(strong, nonatomic) IBOutlet NSPopUpButton *auxiliaryActionPopup;

@end

@implementation NCOpsDeletionDialog {
    nc::ops::DeletionType m_DefaultType;
    nc::ops::DeletionType m_ResultType;

    std::shared_ptr<std::vector<VFSListingItem>> m_Items;
    bool m_AllowMoveToTrash;
}

@synthesize allowMoveToTrash = m_AllowMoveToTrash;
@synthesize resultType = m_ResultType;
@synthesize defaultType = m_DefaultType;
@synthesize Label;
@synthesize primaryActionButton;
@synthesize auxiliaryActionPopup;

- (id)initWithItems:(const std::shared_ptr<std::vector<VFSListingItem>> &)_items
{
    using namespace nc::ops;
    const auto nib_path = [Bundle() pathForResource:@"DeletionDialog" ofType:@"nib"];
    self = [super initWithWindowNibPath:nib_path owner:self];
    if( self ) {
        m_AllowMoveToTrash = true;
        m_DefaultType = DeletionType::Permanent;
        m_ResultType = DeletionType::Permanent;
        m_Items = _items;
    }

    return self;
}

- (void)windowDidLoad
{
    using namespace nc::ops;
    [super windowDidLoad];

    if( m_DefaultType == DeletionType::Trash ) {
        self.primaryActionButton.title = localizable::DeletionDialogMoveToTrashTitle();

        [self.auxiliaryActionPopup addItemWithTitle:localizable::DeletionDialogDeletePermanentlyTitle()];
        self.auxiliaryActionPopup.lastItem.target = self;
        self.auxiliaryActionPopup.lastItem.action = @selector(onAuxActionPermDelete:);
    }
    else if( m_DefaultType == DeletionType::Permanent ) {
        self.primaryActionButton.title = localizable::DeletionDialogDeletePermanentlyTitle();

        if( m_AllowMoveToTrash ) {
            [self.auxiliaryActionPopup addItemWithTitle:localizable::DeletionDialogMoveToTrashTitle()];
            self.auxiliaryActionPopup.lastItem.target = self;
            self.auxiliaryActionPopup.lastItem.action = @selector(onAuxActionTrash:);
        }
        else {
            self.auxiliaryActionPopup.enabled = false;
        }
    }

    [self buildTitle];
}

- (IBAction)onPrimaryAction:(id) [[maybe_unused]] _sender
{
    m_ResultType = m_DefaultType;
    [self.window.sheetParent endSheet:self.window returnCode:NSModalResponseOK];
}

- (IBAction)onAuxActionTrash:(id) [[maybe_unused]] _sender
{
    m_ResultType = nc::ops::DeletionType::Trash;
    [self.window.sheetParent endSheet:self.window returnCode:NSModalResponseOK];
}

- (IBAction)onAuxActionPermDelete:(id) [[maybe_unused]] _sender
{
    m_ResultType = nc::ops::DeletionType::Permanent;
    [self.window.sheetParent endSheet:self.window returnCode:NSModalResponseOK];
}

- (IBAction)OnCancelAction:(id) [[maybe_unused]] _sender
{
    [self.window.sheetParent endSheet:self.window returnCode:NSModalResponseCancel];
}

- (void)moveRight:(id)sender
{
    [self.window selectNextKeyView:sender];
}

- (void)moveLeft:(id)sender
{
    [self.window selectPreviousKeyView:sender];
}

- (void)buildTitle
{
    using namespace nc::ops;
    if( m_Items->size() == 1 )
        self.Label.stringValue =
            [NSString stringWithFormat:localizable::DeletionDialogDoYouWantToDeleteSingleMessage(),
                                       [NSString stringWithUTF8String:m_Items->front().FilenameC()]];
    else
        self.Label.stringValue = [NSString stringWithFormat:localizable::DeletionDialogDoYouWantToDeleteMultiMessage(),
                                                            [NSNumber numberWithUnsignedLong:m_Items->size()]];
}

@end
