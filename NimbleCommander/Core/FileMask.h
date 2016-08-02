//
//  FileMask.h
//  Files
//
//  Created by Michael G. Kazakov on 30.07.13.
//  Copyright (c) 2013 Michael G. Kazakov. All rights reserved.
//

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
    
    /**
     * Return true if _mask is a wildcard(s).
     * If it's a set of fixed names or a single word - return false.
     */
    static bool IsWildCard(NSString *_mask);
    
    /**
     * Will try to convert _mask into a wildcard, by preffixing it's parts with "*." or with "*".
     * Return nil on errors.
     */
    static NSString *ToExtensionWildCard(NSString *_mask);

    /**
     * Will try to convert _mask into a wildcard, by preffixing it's parts with "*" and suffixing with "*".
     * Return nil on errors.
     */
    static NSString *ToFilenameWildCard(NSString *_mask);
    
private:
    static bool CompareAgainstSimpleMask(const string& _mask, NSString *_name);
    
    vector< pair<NSRegularExpression*, string> > m_RegExps; // regexp and corresponding simple mask if any
    NSString        *m_Mask;
};
