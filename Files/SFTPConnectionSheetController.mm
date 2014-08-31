//
//  SFTPConnectionSheetController.m
//  Files
//
//  Created by Michael G. Kazakov on 31/08/14.
//  Copyright (c) 2014 Michael G. Kazakov. All rights reserved.
//

#import "SFTPConnectionSheetController.h"

@implementation SFTPConnectionSheetController

- (IBAction)OnConnect:(id)sender
{
        [self endSheet:NSModalResponseOK];
}

- (IBAction)OnClose:(id)sender
{
        [self endSheet:NSModalResponseCancel];
}

@end
