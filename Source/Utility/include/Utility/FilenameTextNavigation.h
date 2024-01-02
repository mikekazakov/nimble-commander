// Copyright (C) 2018-2019 Michael Kazakov. Subject to GNU General Public License version 3.
#pragma once
#include <Cocoa/Cocoa.h>

namespace nc::utility {

class FilenameTextNavigation
{
public:
    static NSCharacterSet * const DefaultStopCharacters;
    static unsigned long NavigateToNextWord(NSString *_string,
                                            unsigned long _location,
                                            NSCharacterSet *_stop_chars = DefaultStopCharacters
                                            );
    static unsigned long NavigateToPreviousWord(NSString *_string,
                                                unsigned long _location,
                                                NSCharacterSet *_stop_chars = DefaultStopCharacters
                                                );
};

}
