//
//  FTPConnectionSheetController.m
//  Files
//
//  Created by Michael G. Kazakov on 17.05.14.
//  Copyright (c) 2014 Michael G. Kazakov. All rights reserved.
//

#import "FTPConnectionSheetController.h"

@implementation FTPConnectionSheetController

- (IBAction)OnConnect:(id)sender
{
    [self endSheet:NSModalResponseOK];
}

- (IBAction)OnClose:(id)sender
{
    [self endSheet:NSModalResponseCancel];
}

@end
