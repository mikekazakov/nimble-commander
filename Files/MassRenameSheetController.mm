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

//    MachTimeBenchmark mtb;
    auto newnames = mr.Rename(*m_Listing, m_Indeces);
    for(size_t i = 0, e = newnames.size(); i!=e; ++i)
        m_LabelsAfter[i].stringValue = [NSString stringWithUTF8StdString:newnames[i]];
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
    m_ActionViews.emplace_back( CopyView(self.referenceAddText) );
    [self.ActionsTable insertRowsAtIndexes:[NSIndexSet indexSetWithIndex:m_ActionViews.size()-1]
                             withAnimation:NSTableViewAnimationEffectFade|NSTableViewAnimationSlideRight];
}

- (MassRename) buildRenameScriptFromUI
{
    MassRename mr;
    
    for(auto i: m_ActionViews) {
        if(auto v = objc_cast<MassRenameSheetAddText>(i)) {
            mr.AddAction( MassRename::AddText(v.text, v.addIn, v.addWhere) );
        }
    }
    
    return mr;
}

@end

//////////////////////////////////////////////////////////////////////////////// Action Views

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
        m_TextToAdd = (NSTextField*)FindViewWithIdentifier(self, @"text_to_add");
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
