//
//  TermTask.h
//  TermPlays
//
//  Created by Michael G. Kazakov on 15.11.13.
//  Copyright (c) 2013 Michael G. Kazakov. All rights reserved.
//

#pragma once
#include <mutex>
#include <vector>
#include <string>

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

    inline void SetOnChildOutput(void (^_)(const void* _d, int _sz)) { m_OnChildOutput = _; };
    inline void SetOnBashPrompt(void (^_)(const char*)) { m_OnBashPrompt = _; };
    
    // launches /bin/bash actually (hardcoded now)
    void Launch(const char *_work_dir, int _sx, int _sy);
    void ChDir(const char *_new_cwd);
    void Execute(const char *_short_fn, const char *_at); // _at can be NULL. if it is the same as CWD - then ignored
    
    
    
    void WriteChildInput(const void *_d, int _sz);
    
    
    
    inline TermState State() const { return m_State; }
    bool GetChildrenList(std::vector<std::string> &_children); // return false immediately if State is Inactive or Dead
    
private:
    void ProcessBashPrompt(const void *_d, int _sz);
    void SetState(TermState _new_state);
    void ShellDied();
    void CleanUp();
    void ReadChildOutput();
    void (^m_OnChildOutput)(const void* _d, int _sz);
    void (^m_OnBashPrompt)(const char *_cwd);

    volatile TermState m_State;
    volatile int m_MasterFD;
    volatile int m_ShellPID;
    int m_CwdPipe[2];
    
    volatile bool m_TemporarySuppressed; // will give no output until the next bash prompt will show m_RequestedCWD path
    char m_RequestedCWD[1024];
    char m_CWD[1024];
    
    std::recursive_mutex m_Lock; // will lock on WriteChildInput or on cleanup process


};
