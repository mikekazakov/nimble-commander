// Copyright (C) 2024 Michael Kazakov. Subject to GNU General Public License version 3.
#pragma once
#include <span>
#include <memory>
#include <vector>
#include <string>
#include <filesystem>

namespace nc::utility {

class Tags
{
public:
    enum class Color : unsigned char
    {
        None = 0,
        Gray = 1,
        Green = 2,
        Purple = 3,
        Blue = 4,
        Yellow = 5,
        Red = 6,
        Orange = 7
    };

    class Tag;

    // Parses the bplist stored as "com.apple.metadata:_kMDItemUserTags" xattr and returns a list of tags contained in
    // it. Returns an empty vector as an error mechanism.
    static std::vector<Tag> ParseMDItemUserTags(std::span<const std::byte> _bytes) noexcept;

    // Parses the "com.apple.FinderInfo" xattr and extracts a tag color if any is present.
    // Returns an empty vector as an error mechanism.
    static std::vector<Tag> ParseFinderInfo(std::span<const std::byte> _bytes) noexcept;
        
    // Loads the contents an the xattrs and processes it with ParseMDItemUserTags
    static std::vector<Tag> ReadMDItemUserTags(int _fd) noexcept;
    
    // Loads the contents an the xattrs and processes it with ParseFinderInfo
    static std::vector<Tag> ReadFinderInfo(int _fd) noexcept;

    // Loads tags from MDItemUserTags (1st priority) or from FinderInfo(2nd priority), works with file handles
    static std::vector<Tag> ReadTags(int _fd) noexcept;
    
    // Loads tags from MDItemUserTags (1st priority) or from FinderInfo(2nd priority), works with file paths
    static std::vector<Tag> ReadTags(const std::filesystem::path &_path) noexcept;
};

// Non-owning class that represent a text label and a color of a tag.
// The address of the label must be aligned by 8 bytes, i.e. at least natural alignment
class Tags::Tag
{
public:
    Tag(const std::string *_label, Color _color) noexcept;
    const std::string &Label() const noexcept;
    Tags::Color Color() const noexcept;
    bool operator==(const Tag &_rhs) const noexcept;
    bool operator!=(const Tag &_rhs) const noexcept;

private:
    const std::string *m_TaggedPtr;
};

} // namespace nc::utility
