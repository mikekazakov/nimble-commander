// Copyright (C) 2013-2018 Michael Kazakov. Subject to GNU General Public License version 3.

#include <regex>
#include <string>
#include <vector>
#include <optional>

namespace nc::utility {

class FileMask
{
public:
    FileMask(const char* _mask);
    FileMask(const std::string &_mask);

    // will return false on empty names regardless of current file mask
    bool MatchName(const char *_name) const;
    bool MatchName(const std::string &_name) const;

    /**
     * Return true if there's no valid mask to match for.
     */
    bool IsEmpty() const;
    
    /**
     * Get current file mask.
     */
    const std::string& Mask() const;
    
    /**
     * Return true if _mask is a wildcard(s).
     * If it's a set of fixed names or a single word - return false.
     */
    static bool IsWildCard(const std::string &_mask);
    
    /**
     * Will try to convert _mask into a wildcard, by preffixing it's parts with "*." or with "*".
     * Return "" on errors.
     */
    static std::string ToExtensionWildCard(const std::string& _mask);

    /**
     * Will try to convert _mask into a wildcard, by preffixing it's parts with "*" and suffixing with "*".
     * Return "" on errors.
     */
    static std::string ToFilenameWildCard(const std::string& _mask);
    
    bool operator ==(const FileMask&_rhs) const noexcept;
    bool operator !=(const FileMask&_rhs) const noexcept;
    
private:
    using ExtFilter = std::pair< std::optional<std::regex>, std::optional<std::string> >;
    std::vector<ExtFilter> m_Masks; // regexp or corresponding simple mask
    std::string m_Mask;
};

}
