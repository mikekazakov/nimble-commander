//
//  TermTask.cpp
//  Files
//
//  Created by Michael G. Kazakov on 28/06/15.
//  Copyright (c) 2015 Michael G. Kazakov. All rights reserved.
//

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
#include "TermTask.h"

TermTask::TermTask()
{
    
}

TermTask::~TermTask()
{
    
    
    
}

int TermTask::SetTermWindow(int _fd,
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

int TermTask::SetupTermios(int _fd)
{
    struct termios term_sett; // Saved terminal settings
    
    // Save the defaults parameters of the slave side of the PTY
    tcgetattr(_fd, &term_sett);
    term_sett.c_iflag = ICRNL | IXON | IXANY | IMAXBEL | BRKINT;
    term_sett.c_oflag = OPOST | ONLCR;
    term_sett.c_cflag = CREAD | CS8 | HUPCL;
    term_sett.c_lflag = ICANON | ISIG | IEXTEN | ECHO | ECHOE | ECHOK | ECHOKE | ECHOCTL;
    term_sett.c_ispeed = /*B38400*/ B230400;
    term_sett.c_ospeed = /*B38400*/ B230400;
    term_sett.c_cc [VINTR] = 3;   /* CTRL+C */
    term_sett.c_cc [VEOF] = 4;    /* CTRL+D */
    return tcsetattr(_fd, /*TCSADRAIN*/TCSANOW, &term_sett);
}

void TermTask::SetupHandlesAndSID(int _slave_fd)
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

static string GetLocale()
{
    // Keep a copy of the current locale setting for this process
    char* backupLocale = setlocale(LC_CTYPE, NULL);
    
    // Start with the locale
    string locale = "en"; // en as a backup for any possible error
    
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
    
    string encoding = "UTF-8"; // hardcoded now. but how uses non-UTF8 nowdays?
    
    // check if locale + encoding is valid
    string test = locale + '.' + encoding;
    if(NULL != setlocale(LC_CTYPE, test.c_str()))
        locale = test;
    
    // Check the locale is valid
    if(NULL == setlocale(LC_CTYPE, locale.c_str()))
        locale = "";
    
    // Restore locale and return
    setlocale(LC_CTYPE, backupLocale);
    return locale;
}

const map<string, string> &TermTask::BuildEnv()
{
    static map<string, string> env;
    static once_flag once;
    call_once(once, []{
        // do it once per app run
        string locale = GetLocale();
        if(!locale.empty())
        {
            env.emplace("LANG", locale);
            env.emplace("LC_COLLATE", locale);
            env.emplace("LC_CTYPE", locale);
            env.emplace("LC_MESSAGES", locale);
            env.emplace("LC_MONETARY", locale);
            env.emplace("LC_NUMERIC", locale);
            env.emplace("LC_TIME", locale);
        }
        else
        {
            env.emplace("LC_CTYPE", "UTF-8");
        }
        
        env.emplace("TERM", "xterm-16color");
        env.emplace("TERM_PROGRAM", "Files.app");
    });
    
    return env;
}

void TermTask::SetEnv(const map<string, string>& _env)
{
    for(auto &i: _env)
        setenv(i.first.c_str(), i.second.c_str(), 1);
}
