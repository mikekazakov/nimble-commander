// Copyright (C) 2014-2018 Michael Kazakov. Subject to GNU General Public License version 3.
#pragma once

#include "Task.h"

namespace nc::term {

class SingleTask : public Task
{
public:
    SingleTask();
    ~SingleTask();
    
    /**
     * _params will be divided by ' ' character. any "\ " entries will be changed to " ".
     */
    void Launch(const char *_full_binary_path, const char *_params, int _sx, int _sy);
    
    inline void SetOnChildDied(std::function<void()> _new_handler);
    void WriteChildInput(const void *_d, size_t _sz);
    
    void ResizeWindow(int _sx, int _sy);
    
    static void EscapeSpaces(char *_buf);
    inline const std::string &TaskBinaryName() const { return m_TaskBinaryName; }
    
private:
    void CleanUp();    
    void ReadChildOutput();
    std::function<void()> m_OnChildDied;
    volatile int    m_MasterFD = -1;
    volatile int    m_TaskPID  = -1;
    int             m_TermSX   = 0;
    int             m_TermSY   = 0;
    std::string     m_TaskBinaryName;
};

inline void SingleTask::SetOnChildDied(std::function<void()> _new_handler)
{
    m_OnChildDied = std::move(_new_handler);
};
    
}
