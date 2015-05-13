//
//  MassRenameSheetController.m
//  Files
//
//  Created by Michael G. Kazakov on 01/05/15.
//  Copyright (c) 2015 Michael G. Kazakov. All rights reserved.
//

#import "MassRenameSheetController.h"
#import "Common.h"
#import "MassRename.h"

static const auto g_MinActionsPaneWidth = 240.;
static const auto g_MinFilenamesPaneWidth = 200.;

static NSView *CopyView(NSView *v)
{
    NSData *arc = [NSKeyedArchiver archivedDataWithRootObject:v];
    NSView *copy = [NSKeyedUnarchiver unarchiveObjectWithData:arc];
    return copy;
}

static NSView *FindViewWithIdentifier(NSView *v, NSString *identifier)
{
    for (NSView *view in v.subviews)
        if ([view.identifier isEqualToString:identifier])
            return view;
    return nil;
}

// hack around NSTableView behaviour
@interface MassRenameSheetActionsTableView : NSTableView
@end
@implementation MassRenameSheetActionsTableView
- (BOOL)validateProposedFirstResponder:(NSResponder *)responder
                              forEvent:(NSEvent *)event
{
    return true;
}
@end

// hack around NSSegmentedControl behaviour
// this allows connected menu to popup instantly (because no action is returned for menu button)
@interface MassRenamePlusMinusButtonsCell : NSSegmentedCell
@end
@implementation MassRenamePlusMinusButtonsCell
- (SEL)action
{
    if( [self menuForSegment:self.selectedSegment] )
        return nil;
    else
        return super.action;
}
@end

@interface NSControl(fire)
- (void) fireAction;
@end
@implementation NSControl(fire)
- (void) fireAction
{
    [self sendAction:self.action to:self.target];
}
@end


//////////////////////////////////////////////////////////////////////////////// MassRenameSheetController

@implementation MassRenameSheetController
{
    vector<NSView*>                 m_ActionViews;
    shared_ptr<const VFSListing>    m_Listing;
    vector<unsigned>                m_Indeces;
  
    
    
    vector<NSTextField*>            m_LabelsBefore;
    vector<NSTextField*>            m_LabelsAfter;
}


- (instancetype) initWithListing:(shared_ptr<const VFSListing>)_listing
                      andIndeces:(vector<unsigned>)_inds
{
    self = [[MassRenameSheetController alloc] init];
    if(self) {
        m_Listing = _listing;
        m_Indeces = _inds;
        
        for(auto i: m_Indeces) {
            auto &e = m_Listing->At(i);
            
            {
                NSTextField *tf = [[NSTextField alloc] initWithFrame:NSRect()];
                tf.stringValue = e.NSName().copy;
                tf.bordered = false;
                tf.editable = true;
                tf.drawsBackground = false;
                m_LabelsBefore.emplace_back(tf);
            }

            {
                NSTextField *tf = [[NSTextField alloc] initWithFrame:NSRect()];
                tf.stringValue = e.NSName().copy;
                tf.bordered = false;
                tf.editable = true;
                tf.drawsBackground = false;
                m_LabelsAfter.emplace_back(tf);
            }
            
            
        }
    }
    return self;
    
}

- (void)windowDidLoad
{
    [super windowDidLoad];
    
    
    m_ActionViews.emplace_back( CopyView(self.referenceAddText) );
    m_ActionViews.emplace_back( CopyView(self.referenceAddText) );    

    
    [self.ActionsTable sizeLastColumnToFit];
    [self.PlusMinusButtons setMenu:self.PlusMenu forSegment:0];
}

- (IBAction)OnCancel:(id)sender
{
    [self endSheet:NSModalResponseStop];
}

- (NSInteger)numberOfRowsInTableView:(NSTableView *)tableView
{
    if( tableView == self.ActionsTable )
        return m_ActionViews.size();
    if( tableView == self.FilenamesTable )
        return m_Indeces.size();
    return 0;
}

- (NSView *)tableView:(NSTableView *)tableView
   viewForTableColumn:(NSTableColumn *)tableColumn
                  row:(NSInteger)row
{
//    NSScrollView
    
    if( tableView == self.ActionsTable ) {
        assert( row >= 0 && row < m_ActionViews.size() );
        return m_ActionViews[row];
    }
    if( tableView == self.FilenamesTable ) {
        if( [tableColumn.identifier isEqualToString:@"original"] ) {
            assert( row >= 0 && row < m_LabelsBefore.size() );
            return m_LabelsBefore[row];
        }
        if( [tableColumn.identifier isEqualToString:@"renamed"] ) {
            assert( row >= 0 && row < m_LabelsAfter.size() );
            return m_LabelsAfter[row];
        }

    }

    return nil;
}

- (CGFloat)tableView:(NSTableView *)tableView heightOfRow:(NSInteger)row
{
    if( tableView == self.ActionsTable ) {
        assert( row >= 0 && row < m_ActionViews.size() );
        return m_ActionViews[row].bounds.size.height;
    }
    if( tableView == self.FilenamesTable ) {
        return 16;
    }
    return 10;
}

-(CGFloat)splitView:(NSSplitView *)splitView constrainMinCoordinate:(CGFloat)proposedMinimumPosition ofSubviewAt:(NSInteger)dividerIndex
{
    return g_MinActionsPaneWidth;
}

-(CGFloat)splitView:(NSSplitView *)splitView constrainMaxCoordinate:(CGFloat)proposedMaximumPosition ofSubviewAt:(NSInteger)dividerIndex
{
    return splitView.frame.size.width - g_MinFilenamesPaneWidth;
}

- (void)splitView:(NSSplitView *)sender resizeSubviewsWithOldSize:(NSSize)oldSize
{
    NSSize full = sender.frame.size;
    
    NSSize left = objc_cast<NSView>(sender.subviews[0]).frame.size;
    left.height = full.height;
    
    NSSize right;
    right.width = full.width  - sender.dividerThickness - left.width;
    right.height = full.height;
    
    objc_cast<NSView>(sender.subviews[0]).frameSize = left;
    objc_cast<NSView>(sender.subviews[1]).frameSize = right;
}

- (void)tableViewSelectionDidChange:(NSNotification *)notification
{
    if( objc_cast<NSTableView>(notification.object) == self.ActionsTable ) {
        bool minus_enabled = self.ActionsTable.selectedRow >= 0;
        [self.PlusMinusButtons setEnabled:minus_enabled forSegment:1];
    }
}

- (IBAction)OnActonChanged:(id)sender
{
    auto mr = [self buildRenameScriptFromUI];

    MachTimeBenchmark mtb;
    auto newnames = mr.Rename(*m_Listing, m_Indeces);
    for(size_t i = 0, e = newnames.size(); i!=e; ++i)
        m_LabelsAfter[i].stringValue = [NSString stringWithUTF8StdString:newnames[i]];
    
    mtb.ResetMicro("permute in: ");
}

- (IBAction)OnPlusMinusClicked:(id)sender
{
    if( self.PlusMinusButtons.selectedSegment == 1 ) {
        auto selected_row = self.ActionsTable.selectedRow;
        if(selected_row >= 0 && selected_row < m_ActionViews.size()) {
            // remove action from UI
            [self.ActionsTable removeRowsAtIndexes:[NSIndexSet indexSetWithIndex:selected_row]
                                     withAnimation:NSTableViewAnimationEffectFade|NSTableViewAnimationSlideLeft];
            // remove corresponding action view from our direct list
            m_ActionViews.erase( next(begin(m_ActionViews), selected_row) );
            
            // update data
            [self OnActonChanged:self];
        }
    }
}

- (IBAction)OnPlusMenuAddText:(id)sender
{
    [self AddNewActionRegardingTableSelection:CopyView(self.referenceAddText)];
}

- (IBAction)OnPlusMenuReplaceText:(id)sender
{
    [self AddNewActionRegardingTableSelection:CopyView(self.referenceReplaceText)];
}

- (void) AddNewActionRegardingTableSelection:(NSView*)_action_view
{
    NSUInteger insert_pos = 0;
    if( self.ActionsTable.selectedRow < 0 ) {
        insert_pos = m_ActionViews.size();
        m_ActionViews.emplace_back(_action_view);
    }
    else {
        insert_pos = self.ActionsTable.selectedRow;
        m_ActionViews.insert( next(begin(m_ActionViews), self.ActionsTable.selectedRow), _action_view);
    }
    
    [self.ActionsTable insertRowsAtIndexes:[NSIndexSet indexSetWithIndex:insert_pos]
                             withAnimation:NSTableViewAnimationEffectFade|NSTableViewAnimationSlideRight];
    
}

- (MassRename) buildRenameScriptFromUI
{
    MassRename mr;
    
    for(auto i: m_ActionViews) {
        if(auto v = objc_cast<MassRenameSheetAddText>(i))
            mr.AddAction( MassRename::AddText(v.text, v.addIn, v.addWhere) );
        else if( auto v = objc_cast<MassRenameSheetReplaceText>(i) )
            mr.AddAction( MassRename::ReplaceText(v.what, v.with, v.replaceIn, v.mode, v.caseSensitive) );
    }
    
    return mr;
}

@end

//////////////////////////////////////////////////////////////////////////////// MassRenameSheetAddText

@implementation MassRenameSheetAddText
{
    NSPopUpButton          *m_AddIn;
    NSPopUpButton          *m_AddWhere;
    NSTextField            *m_TextToAdd;
    string                  m_ValTextToAdd;
    MassRename::ApplyTo     m_ValAddIn;
    MassRename::Position    m_ValAddWhere;
}

@synthesize text = m_ValTextToAdd;
@synthesize addIn = m_ValAddIn;
@synthesize addWhere = m_ValAddWhere;

- (void)viewWillMoveToSuperview:(NSView *)_view
{
    [super viewWillMoveToSuperview:_view];
    if( !m_TextToAdd ) {
        m_TextToAdd = (NSTextField*)FindViewWithIdentifier(self, @"add_text");
        m_TextToAdd.action = @selector(OnTextChanged:);
        m_TextToAdd.target = self;
        m_TextToAdd.delegate = self;
    }
    if( !m_AddIn ) {
        m_AddIn = (NSPopUpButton*)FindViewWithIdentifier(self, @"add_in");
        m_AddIn.action = @selector(OnInChanged:);
        m_AddIn.target = self;
    }
    if( !m_AddWhere ) {
        m_AddWhere = (NSPopUpButton*)FindViewWithIdentifier(self, @"add_where");
        m_AddWhere.action = @selector(OnWhereChanged:);
        m_AddWhere.target = self;
    }
}

- (void)controlTextDidChange:(NSNotification *)notification
{
    if( auto tf = objc_cast<NSTextField>(notification.object) )
        [self OnTextChanged:tf];
}

- (IBAction)OnTextChanged:(id)sender
{
    const char *new_text = m_TextToAdd.stringValue ? m_TextToAdd.stringValue.fileSystemRepresentationSafe : "";
    if( m_ValTextToAdd == new_text )
        return;
    m_ValTextToAdd = new_text;
    [self fireAction];
}

- (IBAction)OnInChanged:(id)sender
{
    auto new_v = MassRename::ApplyTo(m_AddIn.selectedTag);
    if(new_v == m_ValAddIn)
        return;
    m_ValAddIn = new_v;
    [self fireAction];
}

- (IBAction)OnWhereChanged:(id)sender
{
    auto new_v = MassRename::Position(m_AddWhere.selectedTag);
    if(new_v == m_ValAddWhere)
        return;
    m_ValAddWhere = new_v;
    [self fireAction];
}

@end

//////////////////////////////////////////////////////////////////////////////// MassRenameSheetReplaceText

@implementation MassRenameSheetReplaceText
{
    NSPopUpButton                          *m_ReplaceIn;
    NSPopUpButton                          *m_Mode;
    NSButton                               *m_Senstive;
    NSTextField                            *m_What;
    NSTextField                            *m_With;
    
    string                                  m_ValWhat;
    string                                  m_ValWith;
    bool                                    m_ValSensitive;
    MassRename::ApplyTo                     m_ValIn;
    MassRename::ReplaceText::ReplaceMode    m_ValMode;
}

@synthesize what = m_ValWhat;
@synthesize with = m_ValWith;
@synthesize caseSensitive = m_ValSensitive;
@synthesize replaceIn = m_ValIn;
@synthesize mode = m_ValMode;

- (void)viewWillMoveToSuperview:(NSView *)_view
{
    [super viewWillMoveToSuperview:_view];
    if( !m_What ) {
        m_What = objc_cast<NSTextField>(FindViewWithIdentifier(self, @"replace_what"));
        m_What.action = @selector(OnWhatChanged:);
        m_What.target = self;
        m_What.delegate = self;
    }
    if( !m_With ) {
        m_With = objc_cast<NSTextField>(FindViewWithIdentifier(self, @"replace_with"));
        m_With.action = @selector(OnWithChanged:);
        m_With.target = self;
        m_With.delegate = self;
    }
    if( !m_ReplaceIn ) {
        m_ReplaceIn = objc_cast<NSPopUpButton>(FindViewWithIdentifier(self, @"replace_in"));
        m_ReplaceIn.action = @selector(OnInChanged:);
        m_ReplaceIn.target = self;
    }
    if( !m_Mode ) {
        m_Mode = objc_cast<NSPopUpButton>(FindViewWithIdentifier(self, @"replace_mode"));
        m_Mode.action = @selector(OnModeChanged:);
        m_Mode.target = self;
    }
    if( !m_Senstive ) {
        m_Senstive = objc_cast<NSButton>( FindViewWithIdentifier(self, @"replace_casesens"));
        m_Senstive.action = @selector(OnSensChanged:);
        m_Senstive.target = self;
    }
}

- (IBAction)OnInChanged:(id)sender
{
    auto new_v = MassRename::ApplyTo(m_ReplaceIn.selectedTag);
    if(new_v == m_ValIn)
        return;
    m_ValIn = new_v;
    [self fireAction];
}

- (IBAction)OnModeChanged:(id)sender
{
    auto new_v = MassRename::ReplaceText::ReplaceMode(m_Mode.selectedTag);
    if(new_v == m_ValMode)
        return;
    m_ValMode = new_v;
    [self fireAction];
}

- (IBAction)OnSensChanged:(id)sender
{
    bool checked = m_Senstive.state == NSOnState;
    if( checked == m_ValSensitive )
        return;
    m_ValSensitive = checked;
    [self fireAction];
}

- (IBAction)OnWhatChanged:(id)sender
{
    const char *new_text = m_What.stringValue ? m_What.stringValue.fileSystemRepresentationSafe : "";
    if( m_ValWhat == new_text )
        return;
    m_ValWhat = new_text;
    [self fireAction];
}

- (IBAction)OnWithChanged:(id)sender
{
    const char *new_text = m_With.stringValue ? m_With.stringValue.fileSystemRepresentationSafe : "";
    if( m_ValWith == new_text )
        return;
    m_ValWith = new_text;
    [self fireAction];
}

- (void)controlTextDidChange:(NSNotification *)notification
{
    if( objc_cast<NSTextField>(notification.object) == m_With )
        [self OnWithChanged:m_With];
    else if( objc_cast<NSTextField>(notification.object) == m_What )
        [self OnWhatChanged:m_What];
}

@end