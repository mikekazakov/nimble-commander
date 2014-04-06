//
//  TermSingleTask.h
//  Files
//
//  Created by Michael G. Kazakov on 04.04.14.
//  Copyright (c) 2014 Michael G. Kazakov. All rights reserved.
//

#pragma once
#include <mutex>

using namespace std;

class TermSingleTask
{
public:
    TermSingleTask();
    ~TermSingleTask();
    
    /**
     * _params will be divided by ' ' character. any "\ " entries will be changed to " ".
     */
    void Launch(const char *_full_binary_path, const char *_params, int _sx, int _sy);
    
    inline void SetOnChildOutput(void (^_)(const void* _d, int _sz)) { m_OnChildOutput = _; };
    inline void SetOnChildDied(void (^_)()) { m_OnChildDied = _; };
    void WriteChildInput(const void *_d, int _sz);
    
    void ResizeWindow(int _sx, int _sy);
    
    static void EscapeSpaces(char *_buf);
    
private:
    void ReadChildOutput();
    void (^m_OnChildOutput)(const void* _d, int _sz);
    void (^m_OnChildDied)();
    recursive_mutex m_Lock;         // will lock on WriteChildInput or on cleanup process
    volatile int             m_MasterFD = -1;
    volatile int             m_TaskPID  = -1;
    int             m_TermSX   = 0;
    int             m_TermSY   = 0;
};
