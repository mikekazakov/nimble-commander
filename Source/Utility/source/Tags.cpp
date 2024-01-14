// Copyright (C) 2024 Michael Kazakov. Subject to GNU General Public License version 3.
#include "Tags.h"
#include <string_view>
#include <bit>
#include <utility>
#include <fmt/printf.h>
#include <assert.h>
#include <Base/RobinHoodUtil.h>
#include <mutex>
#include <optional>
#include <CoreFoundation/CoreFoundation.h>
#include <Base/CFStackAllocator.h>
#include <Base/CFPtr.h>
#include <memory_resource>
#include <sys/xattr.h>

namespace nc::utility {

// RTFM: https://opensource.apple.com/source/CF/CF-1153.18/CFBinaryPList.c

static constexpr std::string_view g_Prologue = "bplist00";
static constexpr const char *g_XAttrName = "com.apple.metadata:_kMDItemUserTags";

namespace {

struct Trailer {
    uint8_t unused[5];
    uint8_t sort_version;
    uint8_t offset_int_size;
    uint8_t object_ref_size;
    uint64_t num_objects;
    uint64_t top_object;
    uint64_t offset_table_offset;
};
static_assert(sizeof(Trailer) == 32);

} // namespace

static Trailer BSwap(const Trailer &_in_big_endian) noexcept
{
    Trailer t = _in_big_endian;
    t.num_objects = std::byteswap(t.num_objects);
    t.top_object = std::byteswap(t.top_object);
    t.offset_table_offset = std::byteswap(t.offset_table_offset);
    return t;
}

// Reads _sz bytes of BE int and returns it as 64bit LE
static uint64_t GetSizedInt(const std::byte *_ptr, uint64_t _sz) noexcept
{
    switch( _sz ) {
        case 1:
            return *reinterpret_cast<const uint8_t *>(_ptr);
        case 2:
            return std::byteswap(*reinterpret_cast<const uint16_t *>(_ptr));
        case 4:
            return std::byteswap(*reinterpret_cast<const uint32_t *>(_ptr));
        case 8:
            return std::byteswap(*reinterpret_cast<const uint64_t *>(_ptr));
        default:
            return 0; // weird sizes are not supported
    }
}

static const std::string *InternalizeString(std::string_view _str) noexcept
{
    [[clang::no_destroy]] static //
        robin_hood::unordered_node_set<std::string, RHTransparentStringHashEqual, RHTransparentStringHashEqual>
            strings;
    [[clang::no_destroy]] static //
        std::mutex mut;

    std::lock_guard lock{mut};
    if( auto it = strings.find(_str); it != strings.end() ) {
        return &*it;
    }
    else {
        return &*strings.emplace(_str).first;
    }
}

static std::optional<Tags::Tag> ParseTag(std::string_view _tag_rep) noexcept
{
    if( _tag_rep.empty() )
        return {};
    Tags::Color color = Tags::Color::None;
    if( _tag_rep.size() >= 3 &&                    //
        _tag_rep[_tag_rep.size() - 2] == '\x0a' && //
        _tag_rep[_tag_rep.size() - 1] >= '0' &&    //
        _tag_rep[_tag_rep.size() - 1] <= '7' ) {
        color = static_cast<Tags::Color>(_tag_rep.back() - '0');
        _tag_rep.remove_suffix(2);
    }
    return Tags::Tag{InternalizeString(_tag_rep), color};
}

static std::optional<Tags::Tag> ParseTag(std::u16string_view _tag_rep) noexcept
{
    // NB! _tag_rep is BE, not LE!
    if( _tag_rep.empty() )
        return {};

    Tags::Color color = Tags::Color::None;
    if( _tag_rep.size() >= 3 &&                                   //
        std::byteswap(_tag_rep[_tag_rep.size() - 2]) == '\x0a' && //
        std::byteswap(_tag_rep[_tag_rep.size() - 1]) >= '0' &&    //
        std::byteswap(_tag_rep[_tag_rep.size() - 1]) <= '7' ) {
        color = static_cast<Tags::Color>(std::byteswap(_tag_rep.back()) - '0');
        _tag_rep.remove_suffix(2);
    }

    base::CFStackAllocator alloc;
    auto cf_str =
        base::CFPtr<CFStringRef>::adopt(CFStringCreateWithBytesNoCopy(alloc,
                                                                      reinterpret_cast<const UInt8 *>(_tag_rep.data()),
                                                                      _tag_rep.length() * 2,
                                                                      kCFStringEncodingUTF16BE,
                                                                      false,
                                                                      kCFAllocatorNull));
    if( cf_str ) {
        if( const char *cstr = CFStringGetCStringPtr(cf_str.get(), kCFStringEncodingUTF8) )
            return Tags::Tag{InternalizeString(cstr), color};

        const CFIndex length = CFStringGetLength(cf_str.get());
        const CFIndex max_size = CFStringGetMaximumSizeForEncoding(length, kCFStringEncodingUTF8) + 1;
        std::array<char, 4096> mem_buffer;
        std::pmr::monotonic_buffer_resource mem_resource(mem_buffer.data(), mem_buffer.size());
        std::pmr::vector<char> str_buf(max_size, &mem_resource);
        if( CFStringGetCString(cf_str.get(), str_buf.data(), max_size, kCFStringEncodingUTF8) )
            return Tags::Tag{InternalizeString(str_buf.data()), color};
    }
    return {};
}

namespace {

struct VarLen {
    size_t length = 0;
    const std::byte *start = nullptr;
};

} // namespace

static std::optional<VarLen> ExtractVarLen(const std::byte *_byte_marker_ptr) noexcept
{
    assert(_byte_marker_ptr != nullptr);
    const uint8_t byte_marker = *reinterpret_cast<const uint8_t *>(_byte_marker_ptr);
    const uint8_t builtin_length = byte_marker & 0x0F;
    if( builtin_length == 0x0F ) {
        const std::byte *const len_marker_ptr = _byte_marker_ptr + 1;
        const uint8_t len_marker = *reinterpret_cast<const uint8_t *>(len_marker_ptr);
        if( (len_marker & 0xF0) != 0x10 )
            return {}; // corrupted, discard
        const uint64_t len_size = 1 << (len_marker & 0x0F);
        const std::byte *const len_ptr = len_marker_ptr + 1;
        const uint64_t len = GetSizedInt(len_ptr, len_size);
        return VarLen{len, len_ptr + len_size};
    }
    else {
        return VarLen{builtin_length, _byte_marker_ptr + 1};
    }
}

std::vector<Tags::Tag> Tags::ParseMDItemUserTags(const std::span<const std::byte> _bytes) noexcept
{
    if( _bytes.size() <= g_Prologue.size() + sizeof(Trailer) )
        return {};

    if( !std::string_view(reinterpret_cast<const char *>(_bytes.data()), _bytes.size()).starts_with(g_Prologue) )
        return {}; // missing a valid header, bail out

    const Trailer trailer = BSwap(*reinterpret_cast<const Trailer *>(_bytes.data() + _bytes.size() - sizeof(Trailer)));
    const size_t table_size = trailer.num_objects * trailer.offset_int_size;
    if( trailer.num_objects == 0 || trailer.offset_int_size == 0 || trailer.object_ref_size == 0 ||
        trailer.top_object >= trailer.num_objects || trailer.offset_table_offset < g_Prologue.size() ||
        trailer.offset_table_offset + table_size > _bytes.size() - sizeof(trailer) )
        return {}; // corrupted, discard

    const std::byte *const objs_end = _bytes.data() + trailer.offset_table_offset;

    std::vector<Tags::Tag> tags;
    tags.reserve(trailer.num_objects - 1);

    const std::byte *offset_table = _bytes.data() + trailer.offset_table_offset;
    for( size_t obj_ind = 0; obj_ind < trailer.num_objects; ++obj_ind ) {
        const uint64_t offset = GetSizedInt(offset_table, trailer.offset_int_size);
        offset_table += trailer.offset_int_size;
        if( obj_ind == trailer.top_object )
            continue; // not interested in the root object

        const std::byte *const byte_marker_ptr = _bytes.data() + offset;
        if( byte_marker_ptr >= _bytes.data() + _bytes.size() - sizeof(Trailer) )
            return {}; // corrupted offset, discard the whole plist

        const uint8_t byte_marker = *reinterpret_cast<const uint8_t *>(byte_marker_ptr);
        if( (byte_marker & 0xF0) == 0x50 ) { // ASCII string...
            if( const auto vl = ExtractVarLen(byte_marker_ptr); vl && vl->start + vl->length <= objs_end )
                if( auto tag = ParseTag({reinterpret_cast<const char *>(vl->start), vl->length}) )
                    tags.push_back(*tag);
        }
        if( (byte_marker & 0xF0) == 0x60 ) { // Unicode string...
            if( const auto vl = ExtractVarLen(byte_marker_ptr); vl && vl->start + vl->length * 2 <= objs_end )
                if( auto tag = ParseTag({reinterpret_cast<const char16_t *>(vl->start), vl->length}) )
                    tags.push_back(*tag);
        }
    }
    return tags;
}

std::vector<Tags::Tag> Tags::ReadMDItemUserTags(int _fd) noexcept
{
    assert(_fd >= 0);
    std::array<uint8_t, 4096> buf;
    const ssize_t res = fgetxattr(_fd, g_XAttrName, buf.data(), buf.size(), 0, 0);
    if( res < 0 )
        return {};
    return ParseMDItemUserTags({reinterpret_cast<const std::byte *>(buf.data()), static_cast<size_t>(res)});
}

std::vector<Tags::Tag> Tags::ReadMDItemUserTags(const std::filesystem::path &_path) noexcept
{
    const int fd = open(_path.c_str(), O_RDONLY | O_NONBLOCK);
    if( fd < 0 )
        return {};

    auto tags = ReadMDItemUserTags(fd);

    close(fd);

    return tags;
}

Tags::Tag::Tag(const std::string *const _label, const Tags::Color _color) noexcept
    : m_TaggedPtr{reinterpret_cast<const std::string *>(reinterpret_cast<uint64_t>(_label) |
                                                        static_cast<uint64_t>(std::to_underlying(_color)))}
{
    assert(_label != nullptr);
    assert(std::to_underlying(_color) < 8);
    assert((reinterpret_cast<uint64_t>(_label) & 0x7) == 0);
}

const std::string &Tags::Tag::Label() const noexcept
{
    return *reinterpret_cast<const std::string *>(reinterpret_cast<uint64_t>(m_TaggedPtr) & ~0x7);
}

Tags::Color Tags::Tag::Color() const noexcept
{
    return static_cast<Tags::Color>(reinterpret_cast<uint64_t>(m_TaggedPtr) & 0x7);
}

bool Tags::Tag::operator==(const Tag &_rhs) const noexcept
{
    return Label() == _rhs.Label() && Color() == _rhs.Color();
}

bool Tags::Tag::operator!=(const Tag &_rhs) const noexcept
{
    return !(*this == _rhs);
}

} // namespace nc::utility
