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

static auto g_MyPrivateTableViewDataType = @"MassRenameSheetControllerTableDataViewType";
static const auto g_MinActionsPaneWidth = 260.;
static const auto g_MinFilenamesPaneWidth = 200.;


static NSView *CopyView(NSView *v)
{
    NSData *arc = [NSKeyedArchiver archivedDataWithRootObject:v];
    NSView *copy = [NSKeyedUnarchiver unarchiveObjectWithData:arc];
    return copy;
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
- (void)mouseDown:(NSEvent *)theEvent {
    
    NSInteger clickedRow = [self rowAtPoint:[self convertPoint:theEvent.locationInWindow fromView:nil]];
    bool selected = false;
    if(clickedRow >= 0)
        selected = [self isRowSelected:clickedRow];
    
    [super mouseDown:theEvent];
    
    if( selected )
        [self deselectRow:clickedRow];
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
    [self.ActionsTable registerForDraggedTypes:@[g_MyPrivateTableViewDataType]];
    [self.PlusMinusButtons setMenu:self.PlusMenu forSegment:0];
    
    [self.ActionsTable reloadData];
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

- (IBAction)OnPlusMenuAddSequence:(id)sender
{
    [self AddNewActionRegardingTableSelection:CopyView(self.referenceInsertSequence)];
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
    
    // update data
    [self OnActonChanged:self];
}

- (MassRename) buildRenameScriptFromUI
{
    MassRename mr;
    
    for(auto i: m_ActionViews) {
        if(auto v = objc_cast<MassRenameSheetAddText>(i))
            mr.AddAction( MassRename::AddText(v.text, v.addIn, v.addWhere) );
        else if( auto v = objc_cast<MassRenameSheetReplaceText>(i) )
            mr.AddAction( MassRename::ReplaceText(v.what, v.with, v.replaceIn, v.mode, v.caseSensitive) );
        else if( auto v = objc_cast<MassRenameSheetInsertSequence>(i) )
            mr.AddAction( MassRename::AddSeq(v.insertIn, v.insertWhere, v.start, v.step, v.width, v.prefix, v.suffix) );        
    }
    
    return mr;
}

- (NSDragOperation)tableView:(NSTableView *)aTableView validateDrop:(id < NSDraggingInfo >)info proposedRow:(NSInteger)row proposedDropOperation:(NSTableViewDropOperation)operation
{
    if(aTableView == self.ActionsTable)
        return operation == NSTableViewDropOn ? NSDragOperationNone : NSDragOperationMove;
    return NSDragOperationNone;
}

- (BOOL)tableView:(NSTableView *)aTableView writeRowsWithIndexes:(NSIndexSet *)rowIndexes toPasteboard:(NSPasteboard *)pboard
{
    if(aTableView == self.ActionsTable) {
        [pboard declareTypes:@[g_MyPrivateTableViewDataType] owner:self];
        [pboard setData:[NSKeyedArchiver archivedDataWithRootObject:rowIndexes] forType:g_MyPrivateTableViewDataType];
        return true;
    }
    return false;
}

- (BOOL)tableView:(NSTableView *)aTableView
       acceptDrop:(id<NSDraggingInfo>)info
              row:(NSInteger)drag_to
    dropOperation:(NSTableViewDropOperation)operation
{
    if(aTableView == self.ActionsTable) {
        NSIndexSet* inds = [NSKeyedUnarchiver unarchiveObjectWithData:[info.draggingPasteboard dataForType:g_MyPrivateTableViewDataType]];
        NSInteger drag_from = inds.firstIndex;
        
        if(drag_to == drag_from || // same index, above
           drag_to == drag_from + 1) // same index, below
            return false;
        
        if(drag_from < drag_to)
            drag_to--;

        assert(drag_from < m_ActionViews.size());
        assert(drag_to < m_ActionViews.size());

        auto v = m_ActionViews[drag_from];
        m_ActionViews.erase( next(begin(m_ActionViews),drag_from) );
        m_ActionViews.insert( next(begin(m_ActionViews),drag_to), v );
        
        [self.ActionsTable reloadData];
        dispatch_to_main_queue([=]{
            [self OnActonChanged:self];
        });
        return true;
    }

    return false;
}

@end


