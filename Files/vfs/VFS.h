//
//  VFS.h
//  Files
//
//  Created by Michael G. Kazakov on 29.08.13.
//  Copyright (c) 2013 Michael G. Kazakov. All rights reserved.
//

// just a wrapper to include all VFS facilities

#pragma once

#include "VFSDeclarations.h"
#include "VFSError.h"
#include "VFSHost.h"
#include "VFSFile.h"
#include "VFSPath.h"
#include "VFSEasyOps.h"
#include "VFSArchiveProxy.h"
#include "VFSSeqToRandomWrapper.h"

#include "Native/VFSNativeHost.h"
#include "ArcLA/VFSArchiveHost.h"
#include "ArcUnRAR/VFSArchiveUnRARHost.h"
#include "NetFTP/VFSNetFTPHost.h"
#include "NetSFTP/VFSNetSFTPHost.h"
#include "PS/VFSPSHost.h"
#include "XAttr/xattr.h"
