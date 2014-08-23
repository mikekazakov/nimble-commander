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
    
    // will return false on empty names regardless of current file mask
    bool MatchName(NSString *_name) const;
    bool MatchName(const char *_name) const;

    inline bool IsEmpty() const { return m_RegExps.empty(); }
    
    /**
     * Can return nil on case of empty file mask.
     */
    NSString *Mask() const { return m_Mask; }
    
    // TODO:
    // static bool IsMask(NSString *_mask);
    // static NSString *ExpandToMask(NSString *_not_mask); <--- ???
private:
    static bool CompareAgainstSimpleMask(const string& _mask, NSString *_name);
    
    vector< pair<NSRegularExpression*, string> > m_RegExps; // regexp and corresponding simple mask if any
    NSString        *m_Mask;
};
