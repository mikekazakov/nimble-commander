//
//  BatchRename.h
//  Files
//
//  Created by Michael G. Kazakov on 14/05/15.
//  Copyright (c) 2015 Michael G. Kazakov. All rights reserved.
//

#pragma once

// + [N] old file name, WITHOUT extension
// + [N1] The first character of the original name
// + [N2-5] Characters 2 to 5 from the old name (totals to 4 characters). Double byte characters (e.g. Chinese, Japanese) are counted as 1 character! The first letter is accessed with '1'.
// + [N2,5] 5 characters starting at character 2
// + [N2-] All characters starting at character 2
// + [N02-9] Characters 2-9, fill from left with zeroes if name shorter than requested (8 in this example): "abc" -> "000000bc"
// + [N 2-9] Characters 2-9, fill from left with spaces if name shorter than requested (8 in this example): "abc" -> "      bc"
// + [N-8,5] 5 characters starting at the 8-last character (counted from the end of the name)
// + [N-8-5] Characters from the 8th-last to the 5th-last character
// + [N2--5] Characters from the 2nd to the 5th-last character
// + [N-5-] Characters from the 5th-last character to the end of the name
// + [A] Old file name, WITH extension (All characters of the name), without the path
//[2-5] Characters 2-5 from the name INCLUDING path and extension (other numbers as in [N] definition)
//[P] Paste name of the parent directory, e.g. when renaming c:\directory\file.txt -> pastes "directory".
//Also working: [P2-5], [P2,5], [P-8,5], [P-8-5] and [P2-], see description of [N] above.
//[G] Grandparent directory (usage: see [P]).
// + [E] Extension
// + [E1-2] Characters 1-2 from the extension (same ranges as in [N] definition)
// + [C] Paste counter, as defined in Define counter field
// + [C10+5:3] Paste counter, define counter settings directly. In this example, start at 10, step by 5, use 3 digits width.
// + Partial definitions like [C10] or [C+5] or [C:3] are also accepted.
//Hint: The fields in Define counter will be ignored if you specify options directly in the [C] field.
// + [C+1/100] New: Fractional number: Paste counter, but increase it only every n files (in this example: every 100 files).
//Can be used to move a specific number of files to a subdirectory,e.g. [C+1/100]\[N]
//[Caa+1] Paste counter, define counter settings directly. In this example, start at aa, step 1 letter, use 2 digits (defined by 'aa' width)
//[C:a] Paste counter, determine digits width automatically, depending on the number of files. Combinations like [C10+10:a] are also allowed.
// + [d] Paste date as defined in current country settings. / is replaced by a dash
// + [Y] Paste year in 4 digit form
// + [y] Paste year in 2 digit form
// + [M] Paste month, always 2 digit
// + [D] Paste day, always 2 digit
// + [t] Paste time, as defined in current country settings. : is replaced by a dot.
// + [h] Paste hours, always in 24 hour 2 digit format
// + [m] Paste minutes, always in 2 digit format
// + [s] Paste seconds, always in 2 digit format
// + [U] All characters after this position in uppercase
// + [L] All characters after this position in lowercase
// + [F] First letter of each word uppercase after this position, all others lowercase
// + [n] All characters after this position again as in original name (upper/lowercase unchanged)
// + [[] Insert square bracket: open
// + []] Insert square bracket: close (cannot be combined with other commands inside the square bracket!)
//[=pluginname.fieldname.unit]
//Insert field named "fieldname" from content plugin named "pluginname". "unit" may be an optional unit (if supported by that field), or a field formatter like YMD for date fields. You can use the [=?] Plugin button to insert plugin fields.
//[=pluginname.fieldname.unit:4-7]
//Same as above, but for partial strings (here: letters 4-7).
//Supports the same ranges as the [N] field (see above), including leading spaces or zeroes.


class BatchRename
{
public:
    struct Range
    {
        unsigned short location, length;
        
        Range();
        Range(unsigned short loc, unsigned short len);
        
        constexpr static unsigned short max_length();
        NSRange toNSRange() const;
        Range intersection(const Range _rhs) const;
        bool intersects(const Range _rhs) const;
        unsigned max() const;
    };
    
    struct TextExtraction
    {
        optional<Range> direct_range = Range{0, Range::max_length()};   // 1st priority
        optional<Range> reverse_range = nullopt;                        // 2nd priority
        unsigned short from_first = 0;
        unsigned short to_last    = 0;
        
        bool space_flag = false;
        bool zero_flag = false;
    };
    
    struct Counter
    {
        long start;
        long step;
        unsigned stripe;
        unsigned width;
    };
    
    struct MaskDecomposition
    {
        NSString *string    = nil;
        bool is_placeholder = false;
        
        MaskDecomposition(NSString *_s, bool _b):string(_s), is_placeholder(_b){}
    };
    
    struct FileInfo
    {
        NSString *filename;     // filename.txt
        NSString *name;         // filename
        NSString *extension;    // txt
        time_t mod_time;
        struct tm mod_time_tm;
        
    };
    
    enum class CaseTransform
    {
        Unchanged   = 0,
        Uppercase   = 1,
        Lowercase   = 2,
        Capitalized = 3
    };
    
    static optional<vector<MaskDecomposition>> DecomposeMaskIntoPlaceholders(NSString *_mask);
    static optional<pair<TextExtraction, int>> ParsePlaceholder_TextExtraction( NSString *_ph, unsigned long _pos ); // action and number of chars eaten if no errors
    static optional<pair<Counter, int>> ParsePlaceholder_Counter( NSString *_ph, unsigned long _pos,
                                                                 long _default_start=1, long _default_step=1, int _default_width = 1, unsigned _default_stripe = 1); // action and number of chars eaten if no errors
    static NSString *ExtractText(NSString *_from, const TextExtraction &_te);
    static NSString *FormatCounter(const Counter &_c, int _file_number);
    
    bool BuildActionsScript( NSString *_mask );
    void SetReplacingOptions(NSString *_search_for,
                             NSString *_replace_with,
                             bool _case_sensitive,
                             bool _only_first,
                             bool _search_in_ext,
                             bool _use_regexp);
    
    
    
    NSString *Rename( const FileInfo &_fi, int _number ) const;
    
    
    
private:
    
    enum class ActionType : short
    {
        Static,
        Filename,
        Name,
        Extension,
        OpenBracket,
        CloseBracket,
        UnchangedCase,
        Uppercase,
        Lowercase,
        Capitalized,
        Counter,
        TimeSeconds,
        TimeMinutes,
        TimeHours,
        TimeDay,
        TimeMonth,
        TimeYear2,
        TimeYear4,
        Time,
        Date
    };

    
    struct Step
    {
        ActionType type;
        short      index;
        Step(ActionType t, short i):type(t), index(i){}
        Step(ActionType t):type(t), index(-1){}
    };
    
    void AddStaticText(NSString *s) {
        m_Steps.emplace_back( ActionType::Static, m_ActionsStatic.size() );
        m_ActionsStatic.emplace_back( s );
    }

    void AddInsertName(const TextExtraction &t) {
        m_Steps.emplace_back( ActionType::Name, m_ActionsName.size() );
        m_ActionsName.emplace_back( t );
    }
    
    void AddInsertExtension(const TextExtraction &t) {
        m_Steps.emplace_back( ActionType::Extension, m_ActionsExtension.size() );
        m_ActionsExtension.emplace_back( t );
    }

    void AddInsertCounter(const Counter &t) {
        m_Steps.emplace_back( ActionType::Counter, m_ActionsCounter.size() );
        m_ActionsCounter.emplace_back( t );
        
    }
    
    struct ReplaceOptions;
    static NSString *DoSearchReplace(const ReplaceOptions &_opts, NSString *_source);
    
    bool ParsePlaceholder( NSString *_ph );

    
    vector<Step>            m_Steps;
    vector<NSString*>       m_ActionsStatic;
    vector<TextExtraction>  m_ActionsName;
    vector<TextExtraction>  m_ActionsExtension;
    vector<Counter>         m_ActionsCounter;

    struct ReplaceOptions {
        NSString *search_for = @"";
        NSString *replace_with = @"";
        bool case_sensitive = false;
        bool only_first = false;
        bool search_in_ext = true;
        bool use_regexp = false;
    }                       m_SearchReplace;
    
    
};

inline BatchRename::Range::Range():
    location(0),
    length(0)
{}

inline BatchRename::Range::Range(unsigned short loc, unsigned short len):
    location(loc),
    length(len)
{}

inline constexpr unsigned short BatchRename::Range::max_length()
{
    return numeric_limits<unsigned short>::max();
}

inline NSRange BatchRename::Range::toNSRange() const
{
    return NSMakeRange(location, length);
}

inline BatchRename::Range BatchRename::Range::intersection(const Range _rhs) const
{
    unsigned short min_v = ::max(location, _rhs.location);
    unsigned max_v = ::min(max(), _rhs.max());
    if( max_v < min_v)
        return {0, 0};
    max_v -= min_v;
    if(max_v > max_length())
        return {min_v, max_length()};
    else
        return {min_v, (unsigned short)max_v};
}

inline bool BatchRename::Range::intersects(const Range _rhs) const
{
    return (max() < _rhs.location || _rhs.max() < location) ? false : true;
}

inline unsigned BatchRename::Range::max() const
{
    return unsigned(location) + unsigned(length);
}
