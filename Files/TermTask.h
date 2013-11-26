//
//  TermTask.h
//  TermPlays
//
//  Created by Michael G. Kazakov on 15.11.13.
//  Copyright (c) 2013 Michael G. Kazakov. All rights reserved.
//

#pragma once
#include <pthread.h>


class TermTask
{
public:
    TermTask();
    
    // launches /bin/bash actually
    void Launch(const char *_work_dir, int _sx, int _sy);
    
    
    void SetOnChildOutput(void (^)(const void* _d, int _sz));
    inline void SetOnBashPrompt(void (^_)(const void* _d, int _sz)) { m_OnBashPrompt = _; };
    
    void WriteChildInput(const void *_d, int _sz);
    
private:
    void ReadChildOutput();
    void (^m_OnChildOutput)(const void* _d, int _sz);
    void (^m_OnBashPrompt)(const void* _d, int _sz);
    
    int m_MasterFD;
//    int m_SlaveFD;
    pthread_mutex_t m_Lock; // will lock on WriteChildInput
    
    int m_CwdPipe[2];
};