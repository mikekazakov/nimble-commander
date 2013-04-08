//
//  OperationDialogController.h
//  Directories
//
//  Created by Pavel Dogurevich on 31.03.13.
//  Copyright (c) 2013 Michael G. Kazakov. All rights reserved.
//

#import "OperationDialogProtocol.h"

// Window controller that can be queued in Operation.
// Use as a superclass for custom window controllers.
// Use ShowDialogForWindow:(NSWindow*)_window to show the dialog,
// CloseDialogWithResult:(int)_result to close the dialog and HideDialog to hide it temporarily.
@interface OperationDialogController : NSWindowController <OperationDialogProtocol>

// Implements methods from OperationDialogProtocol.

@end

