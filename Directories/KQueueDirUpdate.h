//
//  KQueueDirUpdate.h
//  Directories
//
//  Created by Michael G. Kazakov on 06.03.13.
//  Copyright (c) 2013 Michael G. Kazakov. All rights reserved.
//

#pragma once
#import <pthread.h>

class KQueueDirUpdate
{
public:
    static KQueueDirUpdate *Inst();
    
    bool AddWatchPath(const char *_path);

private:
    KQueueDirUpdate();
    KQueueDirUpdate(const KQueueDirUpdate&);
    static void *BgThread(void*);
    void *BgThreadThis(void*);
    int m_QFD;
};


