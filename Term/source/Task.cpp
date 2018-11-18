// Copyright (C) 2014-2018 Michael Kazakov. Subject to GNU General Public License version 3.
#include "Task.h"
#include <sys/select.h>
#include <sys/ioctl.h>
#include <sys/sysctl.h>
#include <sys/stat.h>
#include <stdlib.h>
#include <fcntl.h>
#include <errno.h>
#include <unistd.h>
#include <stdio.h>
#include <termios.h>
#include <locale.h>
#include <CoreFoundation/CoreFoundation.h>

namespace nc::term {

Task::Task()
{
}

Task::~Task()
{
}

void Task::SetOnChildOutput( std::function<void(const void *_d, size_t _sz)> _callback )
{
    auto local = std::lock_guard{m_OnChildOutputLock};
    m_OnChildOutput = std::make_shared<decltype(_callback)>(std::move(_callback));
}

void Task::DoCalloutOnChildOutput( const void *_d, size_t _sz  )
{
    m_OnChildOutputLock.lock();
    auto clbk = m_OnChildOutput;
    m_OnChildOutputLock.unlock();
    
    if( clbk && *clbk && _sz && _d )
        (*clbk)(_d, _sz);
}

int Task::SetTermWindow(int _fd,
                            unsigned short _chars_width,
                            unsigned short _chars_height,
                            unsigned short _pix_width,
                            unsigned short _pix_height)
{
    struct winsize winsize;
    winsize.ws_col = _chars_width;
    winsize.ws_row = _chars_height;
    winsize.ws_xpixel = _pix_width;
    winsize.ws_ypixel = _pix_height;
    return ioctl(_fd, TIOCSWINSZ, (char *)&winsize);
}

int Task::SetupTermios(int _fd)
{
    struct termios term_sett; // Saved terminal settings
    
    // Save the defaults parameters of the slave side of the PTY
    tcgetattr(_fd, &term_sett);
    term_sett.c_iflag = ICRNL | IXON | IXANY | IMAXBEL | BRKINT;
    term_sett.c_oflag = OPOST | ONLCR;
    term_sett.c_cflag = CREAD | CS8 | HUPCL;
    term_sett.c_lflag = ICANON | ISIG | IEXTEN | ECHO | ECHOE | ECHOK | ECHOKE | ECHOCTL;
    term_sett.c_ispeed = B230400;
    term_sett.c_ospeed = B230400;
    term_sett.c_cc [VINTR] = 3;   /* CTRL+C */
    term_sett.c_cc [VEOF] = 4;    /* CTRL+D */
    return tcsetattr(_fd, /*TCSADRAIN*/TCSANOW, &term_sett);
}

void Task::SetupHandlesAndSID(int _slave_fd)
{
    // The slave side of the PTY becomes the standard input and outputs of the child process
    close(0); // Close standard input (current terminal)
    close(1); // Close standard output (current terminal)
    close(2); // Close standard error (current terminal)
    
    dup(_slave_fd); // PTY becomes standard input (0)
    dup(_slave_fd); // PTY becomes standard output (1)
    dup(_slave_fd); // PTY becomes standard error (2)
    
    // Make the current process a new session leader
    setsid();
    
    // As the child is a session leader, set the controlling terminal to be the slave side of the PTY
    // (Mandatory for programs like the shell to make them manage correctly their outputs)
    ioctl(0, TIOCSCTTY, 1);
}

static std::string GetLocale()
{
    // Keep a copy of the current locale setting for this process
    char* backupLocale = setlocale(LC_CTYPE, NULL);
    
    // Start with the locale
    std::string locale = "en"; // en as a backup for any possible error
    
    CFLocaleRef loc = CFLocaleCopyCurrent();
    CFStringRef ident = CFLocaleGetIdentifier( loc );
    
    if( auto l = CFStringGetCStringPtr(ident, kCFStringEncodingUTF8) )
        locale = l;
    else {
        char buf[256];
        if( CFStringGetCString(ident, buf, 255, kCFStringEncodingUTF8) )
            locale = buf;
    }
    CFRelease(loc);
    
    std::string encoding = "UTF-8"; // hardcoded now. but how uses non-UTF8 nowdays?
    
    // check if locale + encoding is valid
    std::string test = locale + '.' + encoding;
    if(NULL != setlocale(LC_CTYPE, test.c_str()))
        locale = test;
    
    // Check the locale is valid
    if(NULL == setlocale(LC_CTYPE, locale.c_str()))
        locale = "";
    
    // Restore locale and return
    setlocale(LC_CTYPE, backupLocale);
    return locale;
}

const std::map<std::string, std::string> &Task::BuildEnv()
{
    static std::map<std::string, std::string> env;
    static std::once_flag once;
    std::call_once(once, []{
        // do it once per app run
        std::string locale = GetLocale();
        if(!locale.empty()) {
            env.emplace("LANG", locale);
            env.emplace("LC_COLLATE", locale);
            env.emplace("LC_CTYPE", locale);
            env.emplace("LC_MESSAGES", locale);
            env.emplace("LC_MONETARY", locale);
            env.emplace("LC_NUMERIC", locale);
            env.emplace("LC_TIME", locale);
        }
        else {
            env.emplace("LC_CTYPE", "UTF-8");
        }
        
        env.emplace("TERM", "xterm-16color");
        env.emplace("TERM_PROGRAM", "Nimble_Commander");
    });
    
    return env;
}

void Task::SetEnv(const std::map<std::string, std::string>& _env)
{
    for(auto &i: _env)
        setenv(i.first.c_str(), i.second.c_str(), 1);
}

unsigned Task::ReadInputAsMuchAsAvailable(int _fd, void *_buf, unsigned _buf_sz, int _usec_wait)
{
    fd_set fdset;
    unsigned already_read = 0;
    int rc = 0;
    do {
        rc = (int)read(_fd, (char*)_buf + already_read, _buf_sz - already_read);
        if(rc <= 0)
            break;
        already_read += rc;
        
        FD_ZERO(&fdset);
        FD_SET(_fd, &fdset);
        timeval tt;
        tt.tv_sec = 0;
        tt.tv_usec = _usec_wait;
        rc = select(_fd + 1, &fdset, NULL, NULL, &tt);
    } while(rc >= 0 &&
            FD_ISSET(_fd, &fdset) &&
            already_read < _buf_sz);
    return already_read;
}

std::string Task::EscapeShellFeed(const std::string &_feed)
{
    static const char to_esc[] = {'|', '&', ';', '<', '>', '(', ')', '$', '\'', '\\',
        '\"', '`', ' ', '\t' };
    std::string result;
    result.reserve( _feed.length() );
    for( auto c: _feed ) {
        if( std::any_of( std::begin(to_esc), std::end(to_esc), [=](auto e){ return c == e; } ) )
            result += '\\';
        result += c;
    }
    return result;
}

static const char *GetImgNameFromPath(const char *_path)
{
    if( !_path )
        return "";
    const char *img_name = strrchr(_path, '/');
    if(img_name)
        img_name++;
    else
        img_name = _path;
    return img_name;
}

void Task::CloseAllFDAbove3()
{
    static const int max_fd = (int)sysconf(_SC_OPEN_MAX);
    for( int fd = 3; fd < max_fd; fd++ )
        close(fd);
}

int Task::RunDetachedProcess(const std::string &_process_path,
                             const std::vector<std::string> &_args)
{
    const int rc = fork();
    if( rc == 0 ) {
        char **argvs = (char**) malloc(sizeof(char*) * (_args.size() + 2));
        argvs[0] = strdup( GetImgNameFromPath(_process_path.c_str()) );
        for(int i = 0; i < _args.size(); ++i)
            argvs[i+1] = strdup(_args[i].c_str());
        argvs[_args.size()+1] = NULL;
        
        CloseAllFDAbove3();
        
        execvp(_process_path.c_str(), argvs);
        
        exit(1); // we never get here in normal condition
    }

    return rc;
}

}
