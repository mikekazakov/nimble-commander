//
//  OperationsSummaryViewController.m
//  Directories
//
//  Created by Pavel Dogurevich on 23.03.13.
//  Copyright (c) 2013 Michael G. Kazakov. All rights reserved.
//

#import "OperationsSummaryViewController.h"

#import "GenericOperationView.h"
#import "OperationsController.h"

@interface NSBoxWithMouseOverProperty : NSBox
@property (nonatomic, readonly) BOOL MouseOver;
@end

@implementation NSBoxWithMouseOverProperty
{
    BOOL m_MouseOver;
}

@synthesize MouseOver = m_MouseOver;

- (void)updateTrackingAreas
{
    // Init a single tracking area which covers whole view.
 
    if ([self.trackingAreas count])
    {
        // Remove previous tracking area.
        assert([self.trackingAreas count] == 1);
        [self removeTrackingArea:self.trackingAreas[0]];
    }
 
    // Add new tracking area.
    int opts = (NSTrackingMouseEnteredAndExited | NSTrackingActiveAlways | NSTrackingEnabledDuringMouseDrag);
    NSTrackingArea *trackingArea = [[NSTrackingArea alloc] initWithRect:[self bounds] options:opts owner:self userInfo:nil];
 
    // Check if mouse inside or outside of the view, and call appropriate method.
    NSPoint mouseLocation = [[self window] mouseLocationOutsideOfEventStream];
    mouseLocation = [self convertPoint:mouseLocation fromView: nil];
 
    static auto dummy_event = [NSEvent otherEventWithType:NSApplicationDefined location:{0,0} modifierFlags:0 timestamp:0 windowNumber:0 context:nil subtype:0 data1:0 data2:0];
    if (NSPointInRect(mouseLocation, [self bounds]))
        [self mouseEntered:dummy_event];
    else
        [self mouseExited:dummy_event];
 
    [self addTrackingArea:trackingArea];
}

- (void)mouseEntered:(NSEvent *)theEvent
{
    if(m_MouseOver == true)
        return;
    
    [self willChangeValueForKey:@"MouseOver"];
    m_MouseOver = true;
    [self didChangeValueForKey:@"MouseOver"];
}

- (void)mouseExited:(NSEvent *)theEvent
{
    if(m_MouseOver == false)
        return;
    
    [self willChangeValueForKey:@"MouseOver"];
    m_MouseOver = false;
    [self didChangeValueForKey:@"MouseOver"];
}

@end

@implementation OperationsSummaryViewController
{
    NSPopover                    *m_Popover;
    
    __unsafe_unretained NSWindow *m_Window;
    OperationsController *m_OperationsController;
    
    NSButton *m_ListButton;
}

@synthesize OperationsController = m_OperationsController;

- (id)initWithController:(OperationsController *)_controller
                  window:(NSWindow*)_wnd
{
    self = [super initWithNibName:@"OperationsSummaryViewController" bundle:nil];
    if (self)
    {
        m_Window = _wnd;
        m_OperationsController = _controller;
        
        [self loadView];
        
        [m_OperationsController addObserver:self forKeyPath:@"OperationsCount" options:0 context:nil];
//        [m_OperationsController addObserver:self forKeyPath:@"OperationsWithDialogsCount" options:0 context:nil];
        
        NSBoxWithMouseOverProperty *box = [[NSBoxWithMouseOverProperty alloc] initWithFrame:NSMakeRect(0, 0, 300, 34)];
        box.titlePosition = NSNoTitle;
        box.contentViewMargins = NSMakeSize(1, 1);
        self.view = box;
        
        NSTextField *op_caption = [[NSTextField alloc] initWithFrame:NSMakeRect(18, 16, 262, 13)];
        op_caption.editable = false;
        op_caption.bordered = false;
        op_caption.drawsBackground = false;
        op_caption.font = [NSFont labelFontOfSize:11];
        op_caption.alignment = NSCenterTextAlignment;
        ((NSTextFieldCell*)op_caption.cell).lineBreakMode = NSLineBreakByTruncatingMiddle;
        ((NSTextFieldCell*)op_caption.cell).usesSingleLineMode = true;
        [op_caption bind:@"value" toObject:self withKeyPath:@"CurrentOperation.Caption" options:nil];
        [op_caption bind:@"hidden" toObject:self withKeyPath:@"CurrentOperation" options:@{NSValueTransformerNameBindingOption:NSIsNilTransformerName}];
        
        NSProgressIndicator *progress = [[NSProgressIndicator alloc] initWithFrame:NSMakeRect(40, 3, 218, 12)];
        progress.style = NSProgressIndicatorBarStyle;
        progress.controlSize = NSMiniControlSize;
        progress.minValue = 0;
        progress.maxValue = 1;
        progress.doubleValue = 0;
        [progress bind:@"value" toObject:self withKeyPath:@"CurrentOperation.Progress" options:nil];
        [progress bind:@"toolTip" toObject:self withKeyPath:@"CurrentOperation.ShortInfo" options:nil];
        [progress bind:@"isIndeterminate" toObject:self withKeyPath:@"CurrentOperation.IsIndeterminate" options:nil];
        [progress bind:@"animate" toObject:self withKeyPath:@"CurrentOperation.IsIndeterminate" options:nil];
        [progress bind:@"hidden" toObject:self withKeyPath:@"CurrentOperation" options:@{NSValueTransformerNameBindingOption:NSIsNilTransformerName}];
        
        NSButton *pause_button = [[NSButton alloc] initWithFrame:NSMakeRect(261, 2, 14, 14)];
        pause_button.image = [NSImage imageNamed:@"pause_icon"];
        pause_button.imagePosition = NSImageOnly;
        pause_button.buttonType = NSMomentaryChangeButton;
        pause_button.bordered = false;
        ((NSButtonCell*)pause_button.cell).imageScaling = NSImageScaleProportionallyUpOrDown;
        [pause_button bind:@"target" toObject:self withKeyPath:@"CurrentOperation" options:@{NSSelectorNameBindingOption:@"Pause"}];
        [pause_button bind:@"hidden" toObject:self withKeyPath:@"CurrentOperation.IsPaused" options:@{NSValueTransformerNameBindingOption:NSIsNilTransformerName}];
        [pause_button bind:@"hidden2" toObject:self withKeyPath:@"CurrentOperation.IsPaused" options:nil];
        [pause_button bind:@"hidden3" toObject:self.view withKeyPath:@"MouseOver" options:@{NSValueTransformerNameBindingOption:NSNegateBooleanTransformerName}];
        
        NSButton *resume_button = [[NSButton alloc] initWithFrame:NSMakeRect(261, 2, 14, 14)];
        resume_button.image = [NSImage imageNamed:NSImageNameRefreshFreestandingTemplate];
        resume_button.imagePosition = NSImageOnly;
        resume_button.buttonType = NSMomentaryChangeButton;
        resume_button.bordered = false;
        ((NSButtonCell*)resume_button.cell).imageScaling = NSImageScaleProportionallyUpOrDown;
        [resume_button bind:@"target" toObject:self withKeyPath:@"CurrentOperation" options:@{NSSelectorNameBindingOption:@"Resume"}];
        [resume_button bind:@"hidden" toObject:self withKeyPath:@"CurrentOperation" options:@{NSValueTransformerNameBindingOption:NSIsNilTransformerName}];
        [resume_button bind:@"hidden2" toObject:self withKeyPath:@"CurrentOperation.IsPaused" options:@{NSValueTransformerNameBindingOption:NSNegateBooleanTransformerName}];
        [resume_button bind:@"hidden3" toObject:self.view withKeyPath:@"MouseOver" options:@{NSValueTransformerNameBindingOption:NSNegateBooleanTransformerName}];
        
        NSButton *abort_button = [[NSButton alloc] initWithFrame:NSMakeRect(277, 2, 14, 14)];
        abort_button.image = [NSImage imageNamed:NSImageNameStopProgressFreestandingTemplate];
        abort_button.imagePosition = NSImageOnly;
        abort_button.buttonType = NSMomentaryChangeButton;
        abort_button.bordered = false;
        ((NSButtonCell*)abort_button.cell).imageScaling = NSImageScaleProportionallyUpOrDown;
        [abort_button bind:@"target" toObject:self withKeyPath:@"CurrentOperation" options:@{NSSelectorNameBindingOption:@"Stop"}];
        [abort_button bind:@"hidden" toObject:self withKeyPath:@"CurrentOperation" options:@{NSValueTransformerNameBindingOption:NSIsNilTransformerName}];
        [abort_button bind:@"hidden2" toObject:self.view withKeyPath:@"MouseOver" options:@{NSValueTransformerNameBindingOption:NSNegateBooleanTransformerName}];
        
        NSButton *quest_button = [[NSButton alloc] initWithFrame:NSMakeRect(24, 2, 14, 14)];
        quest_button.image = [NSImage imageNamed:@"question_icon"];
        quest_button.imagePosition = NSImageOnly;
        quest_button.buttonType = NSMomentaryChangeButton;
        quest_button.bordered = false;
        [quest_button bind:@"target" toObject:self withKeyPath:@"CurrentOperation" options:@{NSSelectorNameBindingOption:@"ShowDialog"}];
        [quest_button bind:@"hidden" toObject:self withKeyPath:@"CurrentOperation" options:@{NSValueTransformerNameBindingOption:NSIsNilTransformerName}];
        [quest_button bind:@"hidden2" toObject:self withKeyPath:@"CurrentOperation.DialogsCount" options:@{NSValueTransformerNameBindingOption:NSNegateBooleanTransformerName}];
        
        NSButton *list_button = [[NSButton alloc] initWithFrame:NSMakeRect(2, 7, 18, 14)];
        list_button.image = [NSImage imageNamed:@"show_oplist_icon"];
        list_button.imagePosition = NSImageOnly;
        list_button.buttonType = NSMomentaryChangeButton;
        list_button.bordered = false;
        list_button.target = self;
        list_button.action = @selector(ShowOpListButtonAction:);
        [list_button bind:@"hidden" toObject:self withKeyPath:@"CurrentOperation" options:@{NSValueTransformerNameBindingOption:NSIsNilTransformerName}];
        
        [self.view addSubview:list_button];
        [self.view addSubview:quest_button];
        [self.view addSubview:resume_button];
        [self.view addSubview:pause_button];
        [self.view addSubview:abort_button];
        [self.view addSubview:op_caption];
        [self.view addSubview:progress];
        
        m_ListButton = list_button;
    }
    
    return self;
}

- (void)dealloc
{
    [m_OperationsController removeObserver:self forKeyPath:@"OperationsCount"];
//    [m_OperationsController removeObserver:self forKeyPath:@"OperationsWithDialogsCount"];
}

- (void)ShowList
{
    if(m_Popover.shown)
        return;

    NSCollectionView *collection = self.CollectionView;
    
    m_Popover = [NSPopover new];
    m_Popover.contentViewController = self.ScrollViewController;
    m_Popover.behavior = NSPopoverBehaviorTransient;
    m_Popover.appearance = [NSAppearance appearanceNamed:NSAppearanceNameAqua];
    
    // Calculate height of the expanded list.
    auto item_width  = collection.itemPrototype.view.frame.size.width;
    auto item_height = collection.itemPrototype.view.frame.size.height;
    auto count = self.OperationsController.OperationsCount;
    if(count > 6)
        count = 6;
    
    [m_Popover.contentViewController.view setFrameSize:NSMakeSize(item_width, count * item_height + 2)];
    [m_Popover showRelativeToRect:m_ListButton.frame
                           ofView:m_ListButton
                    preferredEdge:NSMinYEdge];
}

- (void)observeValueForKeyPath:(NSString *)_keypath ofObject:(id)_object
                        change:(NSDictionary *)_change context:(void *)_context
{
    if (_object == m_OperationsController && [_keypath isEqualToString:@"OperationsCount"])
    {
        // Count of operations is chaged. Update current operation.
        auto count = m_OperationsController.Operations.count;
        if (count == 0)
        {
            self.CurrentOperation = nil;
            if (m_Popover.shown)
                [m_Popover close];
        }
        else
        {
            Operation *first_op = m_OperationsController.Operations[0];
            if (self.CurrentOperation != first_op)
                self.CurrentOperation = first_op;
            
            m_ListButton.image = [NSImage imageNamed:count > 1 ? @"show_oplist_hl_icon" : @"show_oplist_icon"];
        }
        
        return;
    }
    
/*    if (_object == m_OperationsController && [_keypath isEqualToString:@"OperationsWithDialogsCount"])
    {
        // show toolbar if it's hidden
        if(m_OperationsController.OperationsWithDialogsCount > 0 &&
           m_Window != nil &&
           m_Window.toolbar != nil &&
           m_Window.toolbar.isVisible == false)
            m_Window.toolbar.Visible = true;
        return;
    }*/
    
    [super observeValueForKeyPath:_keypath ofObject:_object
                           change:_change context:_context];
}

- (IBAction)ShowOpListButtonAction:(NSButton *)sender
{
    if (m_Popover.shown)
        [m_Popover close];
    else if (m_OperationsController.OperationsCount > 0)
        [self ShowList];
}

@end
