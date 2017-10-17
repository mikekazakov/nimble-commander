//
//  VFSNetFTPInternalsForward.h
//  Files
//
//  Created by Michael G. Kazakov on 17.03.14.
//  Copyright (c) 2014 Michael G. Kazakov. All rights reserved.
//

#pragma once


namespace nc::vfs {

class FTPHost;

namespace ftp {
    struct CURLInstance;
    struct Entry;
    struct Directory;
    struct ReadBuffer;
    struct WriteBuffer;
    class Cache;
    class File;
}

}
