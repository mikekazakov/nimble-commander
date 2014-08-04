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
    FileMask();
    FileMask(NSString *_mask);
    FileMask(const FileMask&);
    FileMask(FileMask&&);
    FileMask& operator=(const FileMask&);
    FileMask& operator=(FileMask&&);
    
    bool MatchName(NSString *_name) const;
    bool MatchName(const char *_name) const;

    inline bool IsEmpty() const { return m_RegExps == nil; }
    NSString *Mask() const { return m_Mask; }
private:
    NSMutableArray  *m_RegExps;
    NSString        *m_Mask;
};
