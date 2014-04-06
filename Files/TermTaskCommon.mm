//
//  TermTaskCommon.cpp
//  Files
//
//  Created by Michael G. Kazakov on 03.04.14.
//  Copyright (c) 2014 Michael G. Kazakov. All rights reserved.
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
#include "TermTaskCommon.h"

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
