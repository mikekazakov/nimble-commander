// Copyright (C) 2013-2022 Michael Kazakov. Subject to GNU General Public License version 3.
#pragma once
#include <string>
#include <string_view>
#include <vector>
#include <variant>
#include <memory>
#include <re2/re2.h>

namespace nc::utility {

class FileMask
{
public:
    enum class Type {
        Mask, // old-style classic mask, supporting wildcards ('*') and placeholders ('?').
              // Can contain multiple such masks separated by commas (',').
        RegEx // a regular expression string
    };

    // Creates an empty file mask that matches nothing
    FileMask() noexcept;

    // Creates a file mask initialized with a the provided string
    // Any invalid input is discarded silenty.
    FileMask(std::string_view _mask, Type _type = Type::Mask);

    // Checks the correctness of the mask.
    // Only RegEx masks can be invalid.
    static bool Validate(std::string_view _mask, Type _type);

    // Matches the provided filename against the filemask.
    // Returns true if the name maches the mask.
    // Will return false on empty names regardless of current file mask.
    // Any input will be normalized into FormC Lowercase format to perform matching.
    bool MatchName(std::string_view _name) const noexcept;

    /**
     * Return true if there's no valid mask to match for.
     */
    bool IsEmpty() const noexcept;

    /**
     * Get current file mask.
     */
    const std::string &Mask() const noexcept;

    /**
     * Return true if _mask is a wildcard(s).
     * If it's a set of fixed names or a single word - return false.
     */
    static bool IsWildCard(const std::string &_mask);

    /**
     * Will try to convert _mask into a wildcard, by preffixing it's parts with "*." or with "*".
     * Return "" on errors.
     */
    static std::string ToExtensionWildCard(const std::string &_mask);

    /**
     * Will try to convert _mask into a wildcard, by preffixing it's parts with "*" and suffixing with "*".
     * Return "" on errors.
     */
    static std::string ToFilenameWildCard(const std::string &_mask);

    bool operator==(const FileMask &_rhs) const noexcept;
    bool operator!=(const FileMask &_rhs) const noexcept;

private:
    using ExtFilter = std::variant<std::shared_ptr<const re2::RE2>, std::string>;

    // A disjunction (OR) of filters, each can be either a regexp or a corresponding simple mask
    std::vector<ExtFilter> m_Masks;

    // The original string this mask was constructed with
    std::string m_Mask;
};

} // namespace nc::utility
