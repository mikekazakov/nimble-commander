//
//  KQueueDirUpdate.cpp
//  Directories
//
//  Created by Michael G. Kazakov on 06.03.13.
//  Copyright (c) 2013 Michael G. Kazakov. All rights reserved.
//

#include "KQueueDirUpdate.h"

#include <sys/types.h>
#include <sys/event.h>
#include <sys/time.h>
#import <pthread.h>

static KQueueDirUpdate *g_Inst = 0;

KQueueDirUpdate::KQueueDirUpdate()
{
    m_QFD = kqueue();
    assert(m_QFD >= 0);
}

KQueueDirUpdate *KQueueDirUpdate::Inst()
{
    if(!g_Inst) g_Inst = new KQueueDirUpdate(); // never deleting object
    return g_Inst;
}

void *KQueueDirUpdate::BgThread(void *v)
{
//     void *BgThreadThis(void*);
    return Inst()->BgThreadThis(v);
}

void *KQueueDirUpdate::BgThreadThis(void *v)
{
    struct kevent		ev;
    struct timespec     timeout = { 1, 0 };
 
    while(true)
    {
        int n = kevent(m_QFD, NULL, 0, &ev, 1, &timeout);
        if (n > 0 && ev.filter == EVFILT_VNODE)
        {
//            char *path = (char*)ev.udata;
//            int a = 10 ;
            

            
            
        }
            
        
        
    }
    
    
//    int a = 10;
    return 0;
}

bool KQueueDirUpdate::AddWatchPath(const char *_path)
{
    
    // open file descriptor
    int fd = open(_path, O_EVTONLY, 0);
    struct kevent ev;
    struct timespec	nullts = { 0, 0 };
    
    char *newpath = (char*)malloc(strlen(_path)+1);
    strcpy(newpath, _path);
    
    EV_SET(&ev, fd, EVFILT_VNODE, EV_ADD | EV_ENABLE | EV_CLEAR,
           NOTE_WRITE | NOTE_EXTEND | NOTE_ATTRIB, 0, newpath);
    
    
    int kerr = kevent(m_QFD, &ev, 1, NULL, 0, &nullts);
    kerr=kerr;
    
    pthread_t tID;
    int tArg = 5120;
    
    // create a pthread
    pthread_create(&tID, NULL, BgThread, &tArg);
    
    
    
    
    
    return true;
}