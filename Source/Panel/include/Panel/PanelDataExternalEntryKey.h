// Copyright (C) 2017-2024 Michael Kazakov. Subject to GNU General Public License version 3.
#pragma once

#include <VFS/VFS.h>
#include <Base/CFPtr.h>
#include <fmt/format.h>

namespace nc::panel::data {

struct ItemVolatileData;

struct ExternalEntryKey {
    ExternalEntryKey() noexcept;
    ExternalEntryKey(const VFSListingItem &_item, const ItemVolatileData &_item_vd);

    std::string name;
    std::string extension;
    nc::base::CFPtr<CFStringRef> display_name;
    uint64_t size = 0;
    time_t mtime = 0;
    time_t btime = 0;
    time_t atime = 0;
    time_t add_time; // -1 means absent
    bool is_dir = false;
    bool is_valid() const noexcept;
};

} // namespace nc::panel::data

template <>
struct fmt::formatter<nc::panel::data::ExternalEntryKey> : fmt::formatter<std::string> {
    constexpr auto parse(fmt::format_parse_context &ctx) { return ctx.begin(); }

    template <typename FormatContext>
    auto format(const nc::panel::data::ExternalEntryKey &_key, FormatContext &_ctx) const
    {

        return fmt::format_to(_ctx.out(),
                              "(name='{}', extension='{}', display='{}', size={}, directory={}, mtime={}, btime={}, "
                              "atime={}, addtime={})",
                              _key.name,
                              _key.extension,
                              _key.display_name ? nc::base::CFStringGetUTF8StdString(_key.display_name.get())
                                                : std::string{},
                              _key.size,
                              _key.is_dir,
                              _key.mtime,
                              _key.btime,
                              _key.atime,
                              _key.add_time);
    }
};
