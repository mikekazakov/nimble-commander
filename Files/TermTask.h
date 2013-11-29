//
//  TermTask.h
//  TermPlays
//
//  Created by Michael G. Kazakov on 15.11.13.
//  Copyright (c) 2013 Michael G. Kazakov. All rights reserved.
//

#pragma once
#include <mutex>

class TermTask
{
public:
    TermTask();
    ~TermTask();
    
    enum TermState {

        // initial state - shell is not initialized and is not running
        StateInactive        = 0,

        // shell is running normally
        StateShell           = 1,
        
        // a child program is running under shell, executed from it's command line
        StateProgramInternal = 2,
        
        // a child program is running under shell, executed from Files' UI
        StateProgramExternal = 3,
        
        // shell died
        StateDead            = 4
    };
    
    // launches /bin/bash actually (hardcoded now)
    void Launch(const char *_work_dir, int _sx, int _sy);
    
    inline void SetOnChildOutput(void (^_)(const void* _d, int _sz)) { m_OnChildOutput = _; };
    inline void SetOnBashPrompt(void (^_)(const void* _d, int _sz)) { m_OnBashPrompt = _; };
    
    
    void ChDir(const char *_new_cwd);
    void WriteChildInput(const void *_d, int _sz);
    
    inline TermState State() const { return m_State; }
    
private:
    void SetState(TermState _new_state);
    void ShellDied();
    void CleanUp();
    void ReadChildOutput();
    void (^m_OnChildOutput)(const void* _d, int _sz);
    void (^m_OnBashPrompt)(const void* _d, int _sz);
    
    int m_MasterFD;
    int m_ShellPID;
    int m_CwdPipe[2];
    std::mutex m_Lock; // will lock on WriteChildInput or on cleanup process
    TermState m_State;
};
