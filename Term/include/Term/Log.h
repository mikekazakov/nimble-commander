// Copyright (C) 2020-2021 Michael Kazakov. Subject to GNU General Public License version 3.
#pragma once

#include <Habanero/SpdlogFacade.h>

namespace nc::term {

class Log : public base::SpdlogFacade<Log>
{
    static nc::base::SpdLogger m_Logger;
    friend SpdlogFacade;
};

} // namespace nc::term
