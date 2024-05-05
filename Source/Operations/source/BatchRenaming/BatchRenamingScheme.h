// Copyright (C) 2015-2023 Michael Kazakov. Subject to GNU General Public License version 3.
#pragma once

#include <VFS/VFS.h>

namespace nc::ops {

class BatchRenamingScheme
{
public:
    struct Range {
        unsigned short location, length;

        Range();
        Range(unsigned short loc, unsigned short len);

        constexpr static unsigned short max_length();
        NSRange toNSRange() const;
        Range intersection(const Range _rhs) const;
        bool intersects(const Range _rhs) const;
        unsigned max() const;
    };

    struct TextExtraction {
        std::optional<Range> direct_range = Range{0, Range::max_length()}; // 1st priority
        std::optional<Range> reverse_range = std::nullopt;                 // 2nd priority
        unsigned short from_first = 0;
        unsigned short to_last = 0;

        bool space_flag = false;
        bool zero_flag = false;
    };

    struct Counter {
        long start;
        long step;
        unsigned stripe;
        unsigned width;
    };

    struct MaskDecomposition {
        NSString *string = nil;
        bool is_placeholder = false;

        MaskDecomposition(NSString *_s, bool _b) : string(_s), is_placeholder(_b) {}
        bool operator==(const MaskDecomposition &_rhs) const noexcept
        {
            return [string isEqualToString:_rhs.string] && is_placeholder == _rhs.is_placeholder;
        }
        bool operator!=(const MaskDecomposition &_rhs) const noexcept { return !(*this == _rhs); }
    };

    struct FileInfo {
        FileInfo() = default;
        FileInfo(VFSListingItem _item);
        NSString *ParentFilename() const;
        NSString *GrandparentFilename() const;

        VFSListingItem item;
        NSString *filename;  // filename.txt
        NSString *name;      // filename
        NSString *extension; // txt
        time_t mod_time;
        struct tm mod_time_tm;
    };

    enum class CaseTransform {
        Unchanged = 0,
        Uppercase = 1,
        Lowercase = 2,
        Capitalized = 3
    };

    static std::optional<std::vector<MaskDecomposition>> DecomposeMaskIntoPlaceholders(NSString *_mask);

    static std::optional<std::pair<TextExtraction, int>>
    ParsePlaceholder_TextExtraction(NSString *_ph,
                                    unsigned long _pos); // action and number of chars eaten if no errors

    static std::optional<std::pair<Counter, int>>
    ParsePlaceholder_Counter(NSString *_ph,
                             unsigned long _pos,
                             long _default_start,
                             long _default_step,
                             int _default_width,
                             unsigned _default_stripe); // action and number of chars eaten if no errors

    static NSString *ExtractText(NSString *_from, const TextExtraction &_te);

    static NSString *FormatCounter(const Counter &_c, int _file_number);

    bool BuildActionsScript(NSString *_mask);

    void SetReplacingOptions(NSString *_search_for,
                             NSString *_replace_with,
                             bool _case_sensitive,
                             bool _only_first,
                             bool _search_in_ext,
                             bool _use_regexp);

    void SetCaseTransform(CaseTransform _ct, bool _apply_to_ext);

    void SetDefaultCounter(long _start, long _step, unsigned _stripe, unsigned _width);

    NSString *Rename(const FileInfo &_fi, int _number) const;

private:
    enum class ActionType : short {
        Static,
        Filename,            // full file name
        Name,                // name without extension and dot
        Extension,           // just extension
        ParentFilename,      // name of a parent dir, i.e. /foo/bar/baz.txt -> bar
        GrandparentFilename, // name of a grandparent dir, i.e. /foo/bar/baz.txt -> foo
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

    struct Step {
        ActionType type;
        short index;
        Step(ActionType t, short i) : type(t), index(i) {}
        Step(ActionType t) : type(t), index(-1) {}
    };

    struct ReplaceOptions {
        NSString *search_for = @"";
        NSString *replace_with = @"";
        bool case_sensitive = false;
        bool only_first = false;
        bool search_in_ext = true;
        bool use_regexp = false;
    };

    struct DefaultCounter {
        long start = 1;
        long step = 1;
        unsigned stripe = 1;
        unsigned width = 1;
    };

    void AddStaticText(NSString *s);
    void AddInsertName(const TextExtraction &t);
    void AddInsertExtension(const TextExtraction &t);
    void AddInsertFilename(const TextExtraction &t);
    void AddInsertParent(const TextExtraction &t);
    void AddInsertGrandparent(const TextExtraction &t);
    void AddInsertCounter(const Counter &t);
    bool ParsePlaceholder(NSString *_ph);
    static NSString *DoSearchReplace(const ReplaceOptions &_opts, NSString *_source);

    std::vector<Step> m_Steps;
    std::vector<NSString *> m_ActionsStatic;
    std::vector<TextExtraction> m_ActionsTextExtraction;
    std::vector<Counter> m_ActionsCounter;
    ReplaceOptions m_SearchReplace;
    CaseTransform m_CaseTransform = CaseTransform::Unchanged;
    bool m_CaseTransformWithExt = false;
    DefaultCounter m_DefaultCounter;
};

inline BatchRenamingScheme::Range::Range() : location(0), length(0)
{
}

inline BatchRenamingScheme::Range::Range(unsigned short loc, unsigned short len) : location(loc), length(len)
{
}

inline constexpr unsigned short BatchRenamingScheme::Range::max_length()
{
    return std::numeric_limits<unsigned short>::max();
}

inline NSRange BatchRenamingScheme::Range::toNSRange() const
{
    return NSMakeRange(location, length);
}

inline BatchRenamingScheme::Range BatchRenamingScheme::Range::intersection(const Range _rhs) const
{
    unsigned short min_v = std::max(location, _rhs.location);
    unsigned max_v = std::min(max(), _rhs.max());
    if( max_v < min_v )
        return {0, 0};
    max_v -= min_v;
    if( max_v > max_length() )
        return {min_v, max_length()};
    else
        return {min_v, static_cast<unsigned short>(max_v)};
}

inline bool BatchRenamingScheme::Range::intersects(const Range _rhs) const
{
    return (max() < _rhs.location || _rhs.max() < location) ? false : true;
}

inline unsigned BatchRenamingScheme::Range::max() const
{
    return unsigned(location) + unsigned(length);
}

} // namespace nc::ops
