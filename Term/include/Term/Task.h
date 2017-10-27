// Copyright (C) 2014-2017 Michael Kazakov. Subject to GNU General Public License version 3.
#pragma once

namespace nc::term {

class Task
{
public:
    Task();
    ~Task(); // NO virtual here
    
    
    void SetOnChildOutput( function<void(const void *_d, size_t _sz)> _callback );
    
    static string EscapeShellFeed(const string &_feed);
    
    
    // TODO: pwd
    static int RunDetachedProcess(const string &_process_path,
                                  const vector<string> &_args);
    
protected:
    void DoCalloutOnChildOutput( const void *_d, size_t _sz  );
    
    
    
    static int SetupTermios(int _fd);
    
    static int SetTermWindow(int _fd,
                      unsigned short _chars_width,
                      unsigned short _chars_height,
                      unsigned short _pix_width = 0,
                      unsigned short _pix_height = 0);
    
    static void SetupHandlesAndSID(int _slave_fd);
    
    static const map<string, string> &BuildEnv();
    static void SetEnv(const map<string, string>& _env);
    static void CloseAllFDAbove3();
    
    // assumes that some data is available already (call only after select()'ing)
    // will block for _usec_wait usecs
    // returns amount of bytes read
    // no error return available
    static unsigned ReadInputAsMuchAsAvailable(int _fd, void *_buf, unsigned _buf_sz, int _usec_wait = 1);
    
    mutable mutex m_Lock;
private:    
    shared_ptr<function<void(const void *_d, size_t _sz)>>  m_OnChildOutput;
    mutex                                                   m_OnChildOutputLock;
    
};

}
