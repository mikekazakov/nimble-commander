//
//  VFS.h
//  Files
//
//  Created by Michael G. Kazakov on 29.08.13.
//  Copyright (c) 2013 Michael G. Kazakov. All rights reserved.
//

// just a wrapper to include all VFS facilities

#pragma once

#import "VFSDeclarations.h"
#import "VFSError.h"
#import "VFSHost.h"
#import "VFSFile.h"
#import "VFSPath.h"
#import "Native/VFSNativeHost.h"
#import "VFSArchiveHost.h"
#import "VFSArchiveUnRARHost.h"
#import "VFSNetFTPHost.h"
#import "VFSNetSFTPHost.h"
#import "VFSPSHost.h"
#import "XAttr/xattr.h"
#import "VFSEasyOps.h"
#import "VFSArchiveProxy.h"
#import "VFSSeqToRandomWrapper.h"
