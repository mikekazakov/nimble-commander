// Copyright (C) 2014-2018 Michael Kazakov. Subject to GNU General Public License version 3.
#pragma once

#include <functional>
#include <vector>
#include <string>
#include <map>
#include <memory>
#include <mutex>

namespace nc::term {

class Task
{
public:
    Task();
    ~Task(); // NO virtual here
    
    
    void SetOnChildOutput( std::function<void(const void *_d, size_t _sz)> _callback );
    
    static std::string EscapeShellFeed(const std::string &_feed);
    
    
    // TODO: pwd
    static int RunDetachedProcess(const std::string &_process_path,
                                  const std::vector<std::string> &_args);
    
protected:
    void DoCalloutOnChildOutput( const void *_d, size_t _sz  );
    
    
    
    static int SetupTermios(int _fd);
    
    static int SetTermWindow(int _fd,
                      unsigned short _chars_width,
                      unsigned short _chars_height,
                      unsigned short _pix_width = 0,
                      unsigned short _pix_height = 0);
    
    static void SetupHandlesAndSID(int _slave_fd);
    
    static const std::map<std::string, std::string> &BuildEnv();
    static void SetEnv(const std::map<std::string, std::string>& _env);
    static void CloseAllFDAbove3();
    
    // assumes that some data is available already (call only after select()'ing)
    // will block for _usec_wait usecs
    // returns amount of bytes read
    // no error return available
    static unsigned ReadInputAsMuchAsAvailable(int _fd,
                                               void *_buf,
                                               unsigned _buf_sz,
                                               int _usec_wait = 1);
    
    mutable std::mutex m_Lock;
private:    
    std::shared_ptr<std::function<void(const void *_d, size_t _sz)>>    m_OnChildOutput;
    std::mutex                                                          m_OnChildOutputLock;
    
};

}
