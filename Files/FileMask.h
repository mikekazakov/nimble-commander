//
//  FileMask.h
//  Files
//
//  Created by Michael G. Kazakov on 30.07.13.
//  Copyright (c) 2013 Michael G. Kazakov. All rights reserved.
//

#import <Cocoa/Cocoa.h>

class FileMask
{
public:
    FileMask(NSString *_mask);
    bool MatchName(NSString *_name) const;
    
private:
    NSMutableArray *m_RegExps;
    FileMask(const FileMask&); // forbid
    void operator=(const FileMask&); // forbid
};
