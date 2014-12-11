//
//  SFTPConnectionSheetController.m
//  Files
//
//  Created by Michael G. Kazakov on 31/08/14.
//  Copyright (c) 2014 Michael G. Kazakov. All rights reserved.
//

#import "SFTPConnectionSheetController.h"
#import "common_paths.h"
#import "Common.h"

static const auto g_SSHdir = CommonPaths::Get(CommonPaths::Home) + ".ssh/";

@implementation SFTPConnectionSheetController

- (id) init
{
    self = [super init];
    if(self) {
        string rsa_path = g_SSHdir + "id_rsa";
        string dsa_path = g_SSHdir + "id_dsa";
        
        if( access(rsa_path.c_str(), R_OK) == 0 )
            self.keypath = [NSString stringWithUTF8StdString:rsa_path];
        else if( access(dsa_path.c_str(), R_OK) == 0 )
            self.keypath = [NSString stringWithUTF8StdString:dsa_path];
    }
    return self;
}

- (IBAction)OnConnect:(id)sender
{
    [self endSheet:NSModalResponseOK];
}

- (IBAction)OnClose:(id)sender
{
    [self endSheet:NSModalResponseCancel];
}

- (IBAction)OnChooseKey:(id)sender
{
    auto initial_dir = access(g_SSHdir.c_str(), X_OK) == 0 ? g_SSHdir : CommonPaths::Get(CommonPaths::Home);
    NSOpenPanel *panel = [NSOpenPanel openPanel];
    panel.allowsMultipleSelection = false;
    panel.canChooseFiles = true;
    panel.canChooseDirectories = false;
    panel.directoryURL = [[NSURL alloc] initFileURLWithPath:[NSString stringWithUTF8StdString:initial_dir]
                                                isDirectory:true];
    [panel beginSheetModalForWindow:self.window
                  completionHandler:^(NSInteger result){
                      if(result == NSFileHandlingPanelOKButton)
                          self.keypath = panel.URL.path;
                  }];
}

@end
