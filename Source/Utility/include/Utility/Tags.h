// Copyright (C) 2024 Michael Kazakov. Subject to GNU General Public License version 3.
#pragma once
#include <span>
#include <memory>
#include <vector>
#include <string>
#include <filesystem>
#include <optional>
#include <utility>
#include <fmt/format.h>

namespace nc::utility {

class Tags
{
public:
    enum class Color : unsigned char {
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

    // Composes a binary blob representing the contents of the "com.apple.metadata:_kMDItemUserTags" xattr corresponding
    // to the specified list of tags. Empty blob is returned if no tags were provided.
    static std::vector<std::byte> BuildMDItemUserTags(std::span<const Tag> _tags) noexcept;

    // Writes the "com.apple.metadata:_kMDItemUserTags" and "com.apple.FinderInfo" xattrs to the specified file
    // according to the provided set of tags.
    static bool WriteTags(int _fd, std::span<const Tag> _tags) noexcept;

    // Writes the "com.apple.metadata:_kMDItemUserTags" and "com.apple.FinderInfo" xattrs to the specified file
    // according to the provided set of tags.
    static bool WriteTags(const std::filesystem::path &_path, std::span<const Tag> _tags) noexcept;

    // Executes a "kMDItemUserTags=*" query by Spotlight to gather all indexed items on the filesystem that contain any
    // tags.
    static std::vector<std::filesystem::path> GatherAllItemsWithTags() noexcept;

    // Executes "kMDItemUserTags=_tag" (conceptually) query by Spotlight to gather all indexed items on the filesystem
    // that contain the specified tag.
    static std::vector<std::filesystem::path> GatherAllItemsWithTag(std::string_view _tag) noexcept;

    // Gather a current set of tags used by the items on the filesystem.
    static std::vector<Tag> GatherAllItemsTags() noexcept;

    // Finds all items on the filesystem that contain the specified tag and change the color of this tag in these items
    // to the specified new color
    static void ChangeColorOfAllItemsWithTag(std::string_view _tag, Color _color) noexcept;

    // Finds all items on the filesystem that contain the specified tag and change the label of this tag in these items
    // to the specified new name
    static void ChangeLabelOfAllItemsWithTag(std::string_view _tag, std::string_view _new_name) noexcept;

    // Adds the specified tag to the existing list of tags of the specified item.
    // It there's a tag with the same label and different color, it will be overwritten.
    static bool AddTag(const std::filesystem::path &_path, const Tag &_tag) noexcept;

    // Removes the specified tag from the existing list of tags of the specified item.
    static bool RemoveTag(const std::filesystem::path &_path, std::string_view _label) noexcept;

    // Removes the specified tag from all items on the filesystem.
    static void RemoveTagFromAllItems(std::string_view _tag) noexcept;
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
    static const std::string *Internalize(std::string_view _label) noexcept;

private:
    const std::string *m_TaggedPtr;
};

} // namespace nc::utility

template <>
struct fmt::formatter<nc::utility::Tags::Tag> : fmt::formatter<std::string> {
    constexpr auto parse(fmt::format_parse_context &ctx) const { return ctx.begin(); }

    template <typename FormatContext>
    auto format(const nc::utility::Tags::Tag &_tag, FormatContext &_ctx) const
    {
        return fmt::format_to(_ctx.out(), "{} ({})", _tag.Label(), std::to_underlying(_tag.Color()));
    }
};

namespace std {

template <>
class hash<nc::utility::Tags::Tag>
{
public:
    size_t operator()(const nc::utility::Tags::Tag &_tag) const noexcept
    {
        return std::hash<std::string>{}(_tag.Label()) + std::to_underlying(_tag.Color());
    }
};

} // namespace std
