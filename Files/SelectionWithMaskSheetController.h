//
//  SelectionWithMaskSheetController.h
//  Files
//
//  Created by Michael G. Kazakov on 30.07.13.
//  Copyright (c) 2013 Michael G. Kazakov. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@interface SelectionWithMaskSheetHistoryEntry : NSObject<NSCoding>
{
@public
    NSString    *mask;
    NSDate      *last_used;
}
@end

@interface SelectionWithMaskSheetHistory : NSObject
+ (SelectionWithMaskSheetHistory*) sharedHistory;
- (NSArray*) History;
- (NSString*) SelectedMaskForWindow:(NSWindow*)_window;
- (void) ReportUsedMask:(NSString*)_mask ForWindow:(NSWindow*)_window;
@end

typedef void (^SelectionWithMaskCompletionHandler)(int result);

@interface SelectionWithMaskSheetController : NSWindowController

@property (strong) IBOutlet NSComboBox *ComboBox;
@property (strong) IBOutlet NSTextField *TitleLabel;


- (id) init;
- (NSString *) Mask;
- (IBAction)OnOK:(id)sender;
- (IBAction)OnCancel:(id)sender;
- (void)ShowSheet:(NSWindow *)_window handler:(SelectionWithMaskCompletionHandler)_handler;
- (void)SetIsDeselect:(bool) _value;

@end
