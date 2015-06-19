//
//  TermShellTask.h
//  TermPlays
//
//  Created by Michael G. Kazakov on 15.11.13.
//  Copyright (c) 2013 Michael G. Kazakov. All rights reserved.
//

#pragma once

class TermShellTask
{
public:
    ~TermShellTask();
    
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
    void Terminate();
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
    
    void ResizeWindow(int _sx, int _sy);
    
    
    void WriteChildInput(const void *_d, int _sz);
    
    
    
    inline TermState State() const { return m_State; }
    
    /**
     * Current working directory. With trailing slash, in form: /Users/migun/.
     * Return string by value to minimize potential chance to get race condition.
     */
    inline string CWD() const { return m_CWD; }
    
    /**
     * returns a list of children excluding topmost shell (ie bash).
     */
    vector<string> ChildrenList();
    
    
    
    inline void Lock()      { m_Lock.lock();   }
    inline void Unlock()    { m_Lock.unlock(); }
    
    /**
     * Returns number of characters filled in _escaped.
     * If returned values equals to _buf_sz - then buffer was exhausted.
     * Returns -1 on any other errors.
     */
    static int EscapeShellFeed(const char *_feed, char *_escaped, size_t _buf_sz);
    
    
private:
    bool IsCurrentWD(const char *_what) const;
    void ProcessBashPrompt(const void *_d, int _sz);
    void SetState(TermState _new_state);
    void ShellDied();
    void CleanUp();
    void ReadChildOutput();
    void (^m_OnChildOutput)(const void* _d, int _sz) = nil;
    void (^m_OnBashPrompt)(const char *_cwd) = nil;

    volatile TermState m_State = StateInactive;
    volatile int m_MasterFD = -1;
    volatile int m_ShellPID = -1;
    int m_CwdPipe[2] = {-1, -1};
    recursive_mutex m_Lock;         // will lock on WriteChildInput or on cleanup process
    volatile bool m_TemporarySuppressed = false; // will give no output until the next bash prompt will show m_RequestedCWD path
    int m_TermSX = 0;
    int m_TermSY = 0;
    string m_RequestedCWD = "";
    string m_CWD = "";
};
