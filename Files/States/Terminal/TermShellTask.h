//
//  TermShellTask.h
//  TermPlays
//
//  Created by Michael G. Kazakov on 15.11.13.
//  Copyright (c) 2013 Michael G. Kazakov. All rights reserved.
//

#pragma once

#include "TermTask.h"

class TermShellTask : public TermTask
{
public:
    ~TermShellTask();
    
    enum class TaskState {

        // initial state - shell is not initialized and is not running
        Inactive        = 0,

        // shell is running normally
        Shell           = 1,
        
        // a child program is running under shell, executed from it's command line
        ProgramInternal = 2,
        
        // a child program is running under shell, executed from NC's UI
        ProgramExternal = 3,
        
        // shell died
        Dead            = 4
    };
    
    enum class ShellType {
        Bash = 0,
        ZSH = 1
    };

    void SetOnPwdPrompt( function<void(const char *_cwd, bool _changed)> _callback );
    void SetOnStateChange( function<void(TaskState _new_state)> _callback );
    
    // launches /bin/bash actually (hardcoded now)
    void Launch(const char *_work_dir);
    void Terminate();
    
    /**
     * Asks shell to change current working directory.
     * TaskState should be Shell, otherwise will do nothing.
     * Does sync I/O on access checking, thus may cause blocking.
     * Thread-safe.
     */
    void ChDir(const char *_new_cwd);
    
    /**
     * executes a binary file in a directory using ./filename.
     * _at can be NULL. if it is the same as CWD - then ignored.
     * _parameters can be NULL. if they are not NULL - this string should be escaped in advance - this function doesn't convert is anyhow.
     */
    void Execute(const char *_short_fn, const char *_at, const char *_parameters);
    
    /**
     * executes a binary by a full path.
     * _parameters can be NULL.
     */
    void ExecuteWithFullPath(const char *_path, const char *_parameters);
    
    /**
     * Can be used in any TermShellTask state.
     * If shell is alive - will send actual resize signal, otherwise will only set internal width and height.
     */
    void ResizeWindow(int _sx, int _sy);
    
    /**
     * Feeds child process with arbitrary input data.
     * Task state should not be Inactive or Dead.
     * Thread-safe.
     */
    void WriteChildInput( string_view _data );
    
    /**
    * Returns the current shell task state.
    * Thread-safe.
    */
    TaskState State() const;
    
    /**
     * Current working directory. With trailing slash, in form: /Users/migun/.
     * Return string by value to minimize potential chance to get race condition.
     * Thread-safe.
     */
    string CWD() const;
    
    /**
     * returns a list of children excluding topmost shell (ie bash).
     * Thread-safe.
     */
    vector<string> ChildrenList() const;
    
    /**
     * Will return -1 if there's no children on shell or on any errors.
     * Based on same mech as ChildrenList() so may be time-costly.
     * Thread-safe.
     */
    int ShellChildPID() const;
    
private:
    
    bool IsCurrentWD(const char *_what) const;
    void ProcessBashPrompt(const void *_d, int _sz);
    void SetState(TaskState _new_state);
    void ShellDied();
    void CleanUp();
    void ReadChildOutput();

    function<void(const char *_cwd, bool _changed)> m_OnPwdPrompt;
    function<void(TaskState _new_state)> m_OnStateChanged;
    volatile TaskState m_State = TaskState::Inactive;
    volatile int m_MasterFD = -1;
    spinlock     m_MasterWriteLock;
    volatile int m_ShellPID = -1;
    int m_CwdPipe[2] = {-1, -1};
    atomic_bool m_TemporarySuppressed{ false }; // will give no output until the next bash prompt will show m_RequestedCWD path
    int m_TermSX = 0;
    int m_TermSY = 0;
    thread m_InputThread;
    string m_RequestedCWD = "";
    string m_CWD = "";
    ShellType m_ShellType = ShellType::ZSH;
    volatile bool m_IsShuttingDown = false;
};
