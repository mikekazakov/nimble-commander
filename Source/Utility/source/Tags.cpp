// Copyright (C) 2024 Michael Kazakov. Subject to GNU General Public License version 3.
#include "Tags.h"
#include <Base/CFPtr.h>
#include <Base/CFStackAllocator.h>
#include <Base/CFString.h>
#include <Base/UnorderedUtil.h>
#include <Base/algo.h>
#include <CoreFoundation/CoreFoundation.h>
#include <CoreServices/CoreServices.h>
#include <algorithm>
#include <bit>
#include <cassert>
#include <fmt/format.h>
#include <fmt/printf.h>
#include <frozen/string.h>
#include <frozen/unordered_map.h>
#include <memory_resource>
#include <mutex>
#include <optional>
#include <pstld/pstld.h>
#include <ranges>
#include <string_view>
#include <sys/xattr.h>
#include <utility>

namespace nc::utility {

// RTFM: https://opensource.apple.com/source/CF/CF-1153.18/CFBinaryPList.c

static_assert(std::is_trivially_copyable_v<Tags::Tag>);
static_assert(std::is_trivially_destructible_v<Tags::Tag>);

static constexpr std::string_view g_Prologue = "bplist00";
static constexpr const char *g_MDItemUserTags = "com.apple.metadata:_kMDItemUserTags";
static constexpr const char *g_FinderInfo = "com.apple.FinderInfo";
[[clang::no_destroy]] static const std::string g_LabelGray = "Gray";
[[clang::no_destroy]] static const std::string g_LabelGreen = "Green";
[[clang::no_destroy]] static const std::string g_LabelPurple = "Purple";
[[clang::no_destroy]] static const std::string g_LabelBlue = "Blue";
[[clang::no_destroy]] static const std::string g_LabelYellow = "Yellow";
[[clang::no_destroy]] static const std::string g_LabelRed = "Red";
[[clang::no_destroy]] static const std::string g_LabelOrange = "Orange";

// Run this script to regenerate the table:
// for i in {0..7}; do key="TG_COLOR_$i"; find /System/Library/CoreServices/Finder.app/Contents/Resources -name
// "Localizable.strings" -exec /usr/libexec/PlistBuddy -c "Print :$key" {} \; | sed -n "s/\(.*\)/{\"&\", $i},/p"; done |
// sort | uniq
static constinit frozen::unordered_map<frozen::string, uint8_t, 236> g_LocalizedToColors{
    {"Abu-Abu", 1},     {"Albastru", 4},      {"Amarelo", 5},
    {"Amarillo", 5},    {"Arancione", 7},     {"Aucune couleur", 0},
    {"Azul", 4},        {"Bez boje", 0},      {"Bíbor", 3},
    {"Biru", 4},        {"Blå", 4},           {"Blau", 4},
    {"Blauw", 4},       {"Blava", 4},         {"Bleu", 4},
    {"Blu", 4},         {"Blue", 4},          {"Brak koloru", 0},
    {"Cam", 7},         {"Cap color", 0},     {"Cinza", 1},
    {"Cinzento", 1},    {"Crvena", 6},        {"Czerwony", 6},
    {"Ei väriä", 0},    {"Fialová", 3},       {"Galben", 5},
    {"Geel", 5},        {"Geen kleur", 0},    {"Gelb", 5},
    {"Giallo", 5},      {"Grå", 1},           {"Grau", 1},
    {"Gray", 1},        {"Green", 2},         {"Grey", 1},
    {"Gri", 1},         {"Grigio", 1},        {"Grijs", 1},
    {"Gris", 1},        {"Grisa", 1},         {"Groen", 2},
    {"Groga", 5},       {"Grön", 2},          {"Grøn", 2},
    {"Grønn", 2},       {"Grün", 2},          {"Gul", 5},
    {"Harmaa", 1},      {"Hijau", 2},         {"Ingen färg", 0},
    {"Ingen farge", 0}, {"Ingen farve", 0},   {"Jaune", 5},
    {"Jingga", 7},      {"Kék", 4},           {"Kelabu", 1},
    {"Keltainen", 5},   {"Không có màu", 0},  {"Kuning", 5},
    {"Kırmızı", 6},     {"Lam", 4},           {"Laranja", 7},
    {"Lila", 3},        {"Lilla", 3},         {"Ljubičasta", 3},
    {"Lục", 2},         {"Mavi", 4},          {"Merah", 6},
    {"Modrá", 4},       {"Mor", 3},           {"Morada", 3},
    {"Morado", 3},      {"Mov", 3},           {"Narancs", 7},
    {"Naranja", 7},     {"Narančasta", 7},    {"Nenhuma Cor", 0},
    {"Nenhuma cor", 0}, {"Nessun colore", 0}, {"Nicio culoare", 0},
    {"Niebieski", 4},   {"Nincs szín", 0},    {"No Color", 0},
    {"No Colour", 0},   {"Ohne Farbe", 0},    {"Orange", 7},
    {"Oranje", 7},      {"Oransje", 7},       {"Oranssi", 7},
    {"Oranye", 7},      {"Oranžová", 7},      {"Paars", 3},
    {"Piros", 6},       {"Plava", 4},         {"Pomarańczowy", 7},
    {"Portocaliu", 7},  {"Punainen", 6},      {"Purple", 3},
    {"Purpurowy", 3},   {"Red", 6},           {"Renk Yok", 0},
    {"Röd", 6},         {"Rød", 6},           {"Rojo", 6},
    {"Rood", 6},        {"Rosso", 6},         {"Rot", 6},
    {"Rouge", 6},       {"Roxo", 3},          {"Roșu", 6},
    {"Sárga", 5},       {"Sarı", 5},          {"Sin color", 0},
    {"Sininen", 4},     {"Siva", 1},          {"Sivá", 1},
    {"Szary", 1},       {"Szürke", 1},        {"Taronja", 7},
    {"Tía", 3},         {"Tiada Warna", 0},   {"Tidak Ada Warna", 0},
    {"Turuncu", 7},     {"Ungu", 3},          {"Vàng", 5},
    {"Verda", 2},       {"Verde", 2},         {"Vermelho", 6},
    {"Vermella", 6},    {"Vert", 2},          {"Vihreä", 2},
    {"Viola", 3},       {"Violet", 3},        {"Violetti", 3},
    {"Xám", 1},         {"Yellow", 5},        {"Yeşil", 2},
    {"Zelena", 2},      {"Zelená", 2},        {"Zielony", 2},
    {"Zöld", 2},        {"Žádná barva", 0},   {"Šedá", 1},
    {"Červená", 6},     {"Žiadna farba", 0},  {"Žltá", 5},
    {"Žlutá", 5},       {"Żółty", 5},         {"Žuta", 5},
    {"색상 없음", 0},   {"لا يوجد لون", 0},   {"灰色", 1},
    {"회색", 1},        {"綠色", 2},          {"绿色", 2},
    {"紫色", 3},        {"蓝色", 4},          {"藍色", 4},
    {"黃色", 5},        {"黄色", 5},          {"Đỏ", 6},
    {"紅色", 6},        {"红色", 6},          {"橙色", 7},
    {"कोई रंग नहीं", 0},  {"ללא צבע", 0},       {"Без цвета", 0},
    {"无颜色", 0},      {"グレイ", 1},        {"हरा", 2},
    {"초록색", 2},      {"Μοβ", 3},           {"보라색", 3},
    {"ブルー", 4},      {"파란색", 4},        {"노란색", 5},
    {"लाल", 6},         {"レッド", 6},        {"빨간색", 6},
    {"주황색", 7},      {"沒有顏色", 0},      {"Γκρι", 1},
    {"אפור", 1},        {"धूसर", 1},           {"ירוק", 2},
    {"أخضر", 2},        {"グリーン", 2},      {"סגול", 3},
    {"パープル", 3},    {"Μπλε", 4},          {"כחול", 4},
    {"أزرق", 4},        {"नीला", 4},          {"צהוב", 5},
    {"أصفر", 5},        {"पीला", 5},          {"イエロー", 5},
    {"אדום", 6},        {"أحمر", 6},          {"כתום", 7},
    {"オレンジ", 7},    {"Немає кольору", 0}, {"カラーなし", 0},
    {"Серый", 1},       {"Сірий", 1},         {"رمادي", 1},
    {"สีเทา", 1},        {"Синий", 4},         {"Синій", 4},
    {"สีแดง", 6},        {"สีส้ม", 7},           {"Κανένα χρώμα", 0},
    {"जामुनी", 3},       {"สีม่วง", 3},          {"Желтый", 5},
    {"Жовтий", 5},      {"नारंगी", 7},         {"ไม่มีสี", 0},
    {"Πράσινο", 2},     {"Зелений", 2},       {"Зеленый", 2},
    {"สีเขียว", 2},       {"Лиловый", 3},       {"أرجواني", 3},
    {"Κίτρινο", 5},     {"Κόκκινο", 6},       {"Красный", 6},
    {"برتقالي", 7},     {"Бузковий", 3},      {"สีเหลือง", 5},
    {"Червоний", 6},    {"สีน้ำเงิน", 4},        {"Πορτοκαλί", 7},
    {"Оранжевий", 7},   {"Оранжевый", 7},
};

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
    using Set = ankerl::unordered_dense::segmented_set<std::string, UnorderedStringHashEqual, UnorderedStringHashEqual>;
    [[clang::no_destroy]] static Set strings;
    [[clang::no_destroy]] static std::mutex mut;

    const std::lock_guard lock{mut};
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

    std::optional<Tags::Color> color;
    if( _tag_rep.size() >= 3 &&                                   //
        std::byteswap(_tag_rep[_tag_rep.size() - 2]) == '\x0a' && //
        std::byteswap(_tag_rep[_tag_rep.size() - 1]) >= '0' &&    //
        std::byteswap(_tag_rep[_tag_rep.size() - 1]) <= '7' ) {
        color = static_cast<Tags::Color>(std::byteswap(_tag_rep.back()) - '0');
        _tag_rep.remove_suffix(2);
    }

    const base::CFStackAllocator alloc;
    auto cf_str =
        base::CFPtr<CFStringRef>::adopt(CFStringCreateWithBytesNoCopy(alloc,
                                                                      reinterpret_cast<const UInt8 *>(_tag_rep.data()),
                                                                      _tag_rep.length() * 2,
                                                                      kCFStringEncodingUTF16BE,
                                                                      false,
                                                                      kCFAllocatorNull));
    if( !cf_str )
        return {};

    const std::string *label = nullptr;
    if( const char *cstr = CFStringGetCStringPtr(cf_str.get(), kCFStringEncodingUTF8) ) {
        label = InternalizeString(cstr);
    }
    else {
        const CFIndex length = CFStringGetLength(cf_str.get());
        const CFIndex max_size = CFStringGetMaximumSizeForEncoding(length, kCFStringEncodingUTF8) + 1;
        std::array<char, 4096> mem_buffer;
        std::pmr::monotonic_buffer_resource mem_resource(mem_buffer.data(), mem_buffer.size());
        std::pmr::vector<char> str_buf(max_size, &mem_resource);
        if( CFStringGetCString(cf_str.get(), str_buf.data(), max_size, kCFStringEncodingUTF8) )
            label = InternalizeString(str_buf.data());
    }

    if( label == nullptr )
        return {};

    if( color == std::nullopt ) {
        // Old versions of MacOS can write only a label without the tag color index, relying on the value of the label
        // to deduce the color. That's for "base" colors. In these cases - try to do the same.
        auto it = g_LocalizedToColors.find(frozen::string(*label));
        color = it == g_LocalizedToColors.end() ? Tags::Color::None : Tags::Color{it->second};
    }

    return Tags::Tag{label, *color};
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
        return VarLen{.length = len, .start = len_ptr + len_size};
    }
    else {
        return VarLen{.length = builtin_length, .start = _byte_marker_ptr + 1};
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

std::vector<Tags::Tag> Tags::ParseFinderInfo(std::span<const std::byte> _bytes) noexcept
{
    if( _bytes.size() != 32 )
        return {};

    const uint8_t b = (static_cast<uint8_t>(_bytes[9]) & 0xF) >> 1;
    switch( b ) {
        case 0:
            return {};
        case 1:
            return {Tag{&g_LabelGray, Color::Gray}};
        case 2:
            return {Tag{&g_LabelGreen, Color::Green}};
        case 3:
            return {Tag{&g_LabelPurple, Color::Purple}};
        case 4:
            return {Tag{&g_LabelBlue, Color::Blue}};
        case 5:
            return {Tag{&g_LabelYellow, Color::Yellow}};
        case 6:
            return {Tag{&g_LabelRed, Color::Red}};
        case 7:
            return {Tag{&g_LabelOrange, Color::Orange}};
        default:
            return {};
    }
}

static void SetFinderInfoLabel(std::span<uint8_t, 32> _bytes, Tags::Color _color) noexcept
{
    if( _bytes.size() == 32 ) {
        const uint8_t orig_b = _bytes[9];
        const uint8_t new_b = (orig_b & 0xF1) | static_cast<uint8_t>(std::to_underlying(_color) << 1);
        _bytes[9] = new_b;
    }
}

std::vector<Tags::Tag> Tags::ReadMDItemUserTags(int _fd) noexcept
{
    assert(_fd >= 0);
    std::array<uint8_t, 4096> buf;
    const ssize_t res = fgetxattr(_fd, g_MDItemUserTags, buf.data(), buf.size(), 0, 0);
    if( res < 0 )
        return {};
    return ParseMDItemUserTags({reinterpret_cast<const std::byte *>(buf.data()), static_cast<size_t>(res)});
}

std::vector<Tags::Tag> Tags::ReadFinderInfo(int _fd) noexcept
{
    assert(_fd >= 0);
    std::array<uint8_t, 32> buf;
    const ssize_t res = fgetxattr(_fd, g_FinderInfo, buf.data(), buf.size(), 0, 0);
    if( res != buf.size() )
        return {};
    return ParseFinderInfo({reinterpret_cast<const std::byte *>(buf.data()), buf.size()});
}

std::vector<Tags::Tag> Tags::ReadTags(int _fd) noexcept
{
    assert(_fd >= 0);

    // it's faster to first get a list of xattrs and only if one was found to read it than to try reading upfront as
    // a probing mechanism.
    std::array<char, 8192> buf; // Given XATTR_MAXNAMELEN=127, this allows to read up to 64 max-len names
    const ssize_t res = flistxattr(_fd, buf.data(), buf.size(), 0);
    if( res <= 0 )
        return {};

    // 1st - try MDItemUserTags
    const bool has_usertags =
        memmem(buf.data(), res, g_MDItemUserTags, std::string_view{g_MDItemUserTags}.length() + 1) != nullptr;
    if( has_usertags ) {
        auto tags = ReadMDItemUserTags(_fd);
        if( !tags.empty() )
            return tags;
    }

    // 2nd - try FinderInfo
    const bool has_finfo =
        memmem(buf.data(), res, g_FinderInfo, std::string_view{g_FinderInfo}.length() + 1) != nullptr;
    if( !has_finfo )
        return {};

    return ReadFinderInfo(_fd);
}

std::vector<Tags::Tag> Tags::ReadTags(const std::filesystem::path &_path) noexcept
{
    const int fd = open(_path.c_str(), O_RDONLY | O_NONBLOCK);
    if( fd < 0 )
        return {};

    auto tags = ReadTags(fd);

    close(fd);

    return tags;
}

static void WriteVarSize(unsigned char _marker_type, size_t _size, std::pmr::vector<std::byte> &_dst)
{
    if( _size < 15 ) {
        _dst.push_back(std::byte{static_cast<unsigned char>(_marker_type + _size)});
    }
    else if( _size < 256 ) {
        _dst.push_back(std::byte{static_cast<unsigned char>(_marker_type + 15)});
        _dst.push_back(std::byte{0x10});
        _dst.push_back(std::byte{static_cast<unsigned char>(_size)});
    }
    else if( _size < 65536 ) {
        _dst.push_back(std::byte{static_cast<unsigned char>(_marker_type + 15)});
        _dst.push_back(std::byte{0x11});
        _dst.push_back(std::byte{static_cast<unsigned char>(_size >> 8)});
        _dst.push_back(std::byte{static_cast<unsigned char>(_size & 0xFF)});
    }
    else {
        _dst.push_back(std::byte{static_cast<unsigned char>(_marker_type + 15)});
        _dst.push_back(std::byte{0x12});
        _dst.push_back(std::byte{static_cast<unsigned char>((_size >> 24) & 0xFF)});
        _dst.push_back(std::byte{static_cast<unsigned char>((_size >> 16) & 0xFF)});
        _dst.push_back(std::byte{static_cast<unsigned char>((_size >> 8) & 0xFF)});
        _dst.push_back(std::byte{static_cast<unsigned char>((_size >> 0) & 0xFF)});
    }
    // not supporting sizes larger than 4GB.
    // Finder actually doesn't allow even tags longer that 255 bytes
}

static std::pmr::vector<std::byte> WritePListObject(const Tags::Tag &_tag, std::pmr::memory_resource &_mem) noexcept
{
    // NB! Finder does sometimes skip the color information if the label text matches some of the predefined ones.
    // I don't understand the logic on write it makes these decisions.
    // It's possible to do that as well, but then binary blobs will be a bit different - need to update the test corpus.
    // So for now the color information is written unconditionally (of course if that color is not None)
    std::pmr::vector<std::byte> dst(&_mem);
    const std::string &label = _tag.Label();
    const bool is_ascii = std::ranges::all_of(label, [](auto _c) { return static_cast<unsigned char>(_c) <= 0x7F; });
    if( is_ascii ) {
        const size_t len_color = _tag.Color() == Tags::Color::None ? 0 : 2;
        const size_t len = label.length() + len_color;

        // write the byte marker and size
        WriteVarSize(0x50, len, dst);

        // write the label
        dst.insert(dst.end(),
                   reinterpret_cast<const std::byte *>(label.data()),
                   reinterpret_cast<const std::byte *>(label.data() + label.length()));
        if( len_color != 0 ) {
            // write the color if it's not None
            dst.push_back(std::byte{'\x0a'});
            dst.push_back(std::byte{static_cast<unsigned char>('0' + std::to_underlying(_tag.Color()))});
        }
        return dst;
    }
    else {
        // Build CF strings out of our label
        const base::CFStackAllocator alloc;
        auto cf_str =
            base::CFPtr<CFStringRef>::adopt(CFStringCreateWithBytesNoCopy(alloc,
                                                                          reinterpret_cast<const UInt8 *>(label.data()),
                                                                          label.length(),
                                                                          kCFStringEncodingUTF8,
                                                                          false,
                                                                          kCFAllocatorNull));
        if( !cf_str )
            return {}; // corrupted utf8?

        // Calculate the about of bytes required to store it as UTF16BE
        const CFRange range = CFRangeMake(0, CFStringGetLength(cf_str.get()));
        CFIndex target_size = 0;
        const CFIndex converted =
            CFStringGetBytes(cf_str.get(), range, kCFStringEncodingUTF16BE, ' ', false, nullptr, 0, &target_size);
        if( converted != range.length )
            return {}; // corrupted utf8?

        assert(target_size % 2 == 0);
        const size_t len_color = _tag.Color() == Tags::Color::None ? 0 : 2;
        const size_t len = (target_size / 2) + len_color;

        // write the byte marker and size
        WriteVarSize(0x60, len, dst);

        // write the label
        const size_t label_pos = dst.size();
        dst.resize(dst.size() + target_size);
        CFStringGetBytes(cf_str.get(),
                         range,
                         kCFStringEncodingUTF16BE,
                         ' ',
                         false,
                         reinterpret_cast<UInt8 *>(dst.data() + label_pos),
                         target_size,
                         &target_size);

        if( len_color != 0 ) {
            // write the color if it's not None
            dst.push_back(std::byte{'\x00'});
            dst.push_back(std::byte{'\x0a'});
            dst.push_back(std::byte{'\x00'});
            dst.push_back(std::byte{static_cast<unsigned char>('0' + std::to_underlying(_tag.Color()))});
        }

        return dst;
    }
}

std::vector<std::byte> Tags::BuildMDItemUserTags(const std::span<const Tag> _tags) noexcept
{
    if( _tags.empty() )
        return {};

    std::array<char, 4096> mem_buffer;
    std::pmr::monotonic_buffer_resource mem_resource(mem_buffer.data(), mem_buffer.size());

    // Build serialized representation of the tags
    std::pmr::vector<std::pmr::vector<std::byte>> objects(&mem_resource);
    for( auto &tag : _tags ) {
        objects.emplace_back(WritePListObject(tag, mem_resource));
    }

    if( objects.size() > 14 ) {
        // for now the algorithm is simpified to support only up to 14 tags simultaneously, which will be enough unless
        // the system is abused.
        objects.resize(14);
    }

    std::pmr::vector<size_t> offsets; // offset of every object written into the plist will be gathered here

    // Write the magick prologue
    std::pmr::vector<std::byte> plist;
    plist.insert(plist.end(),
                 reinterpret_cast<const std::byte *>(g_Prologue.data()),
                 reinterpret_cast<const std::byte *>(g_Prologue.data() + g_Prologue.length()));

    // Write an array object with up to 14 objects
    offsets.push_back(plist.size());
    plist.push_back(std::byte{static_cast<unsigned char>(0xA0 + objects.size())});

    // Write the object references
    for( size_t i = 0; i < objects.size(); ++i )
        plist.push_back(std::byte{static_cast<unsigned char>(i + 1)});

    // Write the objects themselves
    for( auto &object : objects ) {
        offsets.push_back(plist.size());
        plist.insert(plist.end(), object.begin(), object.end());
    }

    // Deduce the stride of the offset table
    const size_t offset_int_size = 1;
    if( const size_t max = *std::ranges::max_element(offsets); max > 255 ) {
        abort(); // TODO: implement
    }

    // Compose the trailer to be written later on
    Trailer trailer;
    memset(&trailer, 0, sizeof(trailer));
    trailer.offset_int_size = static_cast<uint8_t>(offset_int_size);
    trailer.object_ref_size = 1;
    trailer.num_objects = std::byteswap(static_cast<uint64_t>(objects.size()) + 1);
    trailer.offset_table_offset = std::byteswap(static_cast<uint64_t>(plist.size()));

    // Write the offset table
    for( const size_t offset : offsets ) {
        if( offset_int_size == 1 ) {
            plist.push_back(std::byte{static_cast<unsigned char>(offset)});
        }
        else {
            abort(); // TODO: implement
        }
    }

    // Write the trailer
    plist.insert(plist.end(),
                 reinterpret_cast<const std::byte *>(&trailer),
                 reinterpret_cast<const std::byte *>(&trailer) + sizeof(trailer));

    // Done.
    return {plist.begin(), plist.end()};
}

static bool ClearAllTags(int _fd)
{
    std::array<char, 8192> buf; // Given XATTR_MAXNAMELEN=127, this allows to read up to 64 max-len names
    const ssize_t buf_len = flistxattr(_fd, buf.data(), buf.size(), 0);
    if( buf_len < 0 )
        return false;

    if( buf_len == 0 )
        return true; // nothing to do

    const bool has_usertags = memmem(buf.data(), buf_len, g_MDItemUserTags, strlen(g_MDItemUserTags) + 1) != nullptr;
    if( has_usertags ) {
        if( fremovexattr(_fd, g_MDItemUserTags, 0) != 0 )
            return false;
    }

    const bool has_finfo = memmem(buf.data(), buf_len, g_FinderInfo, strlen(g_FinderInfo) + 1) != nullptr;
    if( has_finfo ) {
        std::array<uint8_t, 32> finder_info;
        const ssize_t ff_read = fgetxattr(_fd, g_FinderInfo, finder_info.data(), finder_info.size(), 0, 0);
        if( ff_read != finder_info.size() )
            return false;

        SetFinderInfoLabel(finder_info, Tags::Color::None);
        if( fsetxattr(_fd, g_FinderInfo, finder_info.data(), finder_info.size(), 0, 0) != 0 )
            return false;
    }

    return true;
}

bool Tags::WriteTags(int _fd, std::span<const Tag> _tags) noexcept
{
    if( _tags.empty() ) {
        return ClearAllTags(_fd);
    }

    // it's faster to first get a list of xattrs and only if one was found to read it than to try reading upfront as
    // a probing mechanism.
    std::array<char, 8192> buf; // Given XATTR_MAXNAMELEN=127, this allows to read up to 64 max-len names
    const ssize_t res = flistxattr(_fd, buf.data(), buf.size(), 0);
    if( res < 0 )
        return false;

    auto blob = BuildMDItemUserTags(_tags);
    if( fsetxattr(_fd, g_MDItemUserTags, blob.data(), blob.size(), 0, 0) != 0 )
        return false;

    std::array<uint8_t, 32> finder_info;
    finder_info.fill(0);
    const bool has_finfo = memmem(buf.data(), res, g_FinderInfo, strlen(g_FinderInfo) + 1) != nullptr;
    if( has_finfo ) {
        const ssize_t ff_read = fgetxattr(_fd, g_FinderInfo, finder_info.data(), finder_info.size(), 0, 0);
        if( ff_read != finder_info.size() )
            return false;
    }
    SetFinderInfoLabel(finder_info, _tags.front().Color());

    return fsetxattr(_fd, g_FinderInfo, finder_info.data(), finder_info.size(), 0, 0) == 0;
}

bool Tags::WriteTags(const std::filesystem::path &_path, std::span<const Tag> _tags) noexcept
{
    const int fd = open(_path.c_str(), O_RDONLY | O_NONBLOCK);
    if( fd < 0 )
        return false;

    const bool res = WriteTags(fd, _tags);

    close(fd);

    return res;
}

std::vector<std::filesystem::path> Tags::GatherAllItemsWithTags() noexcept
{
    const CFStringRef query_string = CFSTR("kMDItemUserTags=*");

    const base::CFPtr<MDQueryRef> query =
        base::CFPtr<MDQueryRef>::adopt(MDQueryCreate(nullptr, query_string, nullptr, nullptr));
    if( !query )
        return {};

    const bool query_result = MDQueryExecute(query.get(), kMDQuerySynchronous);
    if( !query_result )
        return {};

    std::vector<std::filesystem::path> result;
    for( long i = 0, e = MDQueryGetResultCount(query.get()); i < e; ++i ) {
        const MDItemRef item = static_cast<MDItemRef>(const_cast<void *>(MDQueryGetResultAtIndex(query.get(), i)));
        const base::CFPtr<CFStringRef> item_path =
            base::CFPtr<CFStringRef>::adopt(static_cast<CFStringRef>(MDItemCopyAttribute(item, kMDItemPath)));
        if( item_path ) {
            result.emplace_back(base::CFStringGetUTF8StdString(item_path.get()));
        }
    }

    return result;
}

static std::string EscapeForMD(std::string_view _tag) noexcept
{
    constexpr char to_esc[] = {'\'', '\\', '\"'};
    std::string escaped_tag;
    for( auto c : _tag ) {
        if( std::ranges::any_of(to_esc, [=](auto e) { return c == e; }) )
            escaped_tag += '\\';
        escaped_tag += c;
    }
    return escaped_tag;
}

std::vector<std::filesystem::path> Tags::GatherAllItemsWithTag(std::string_view _tag) noexcept
{
    if( _tag.empty() )
        return {};

    const base::CFPtr<CFStringRef> query_string = base::CFPtr<CFStringRef>::adopt(
        base::CFStringCreateWithUTF8StdString(fmt::format("kMDItemUserTags=='{}'", EscapeForMD(_tag))));

    const base::CFPtr<MDQueryRef> query =
        base::CFPtr<MDQueryRef>::adopt(MDQueryCreate(nullptr, query_string.get(), nullptr, nullptr));
    if( !query )
        return {};

    const bool query_result = MDQueryExecute(query.get(), kMDQuerySynchronous);
    if( !query_result )
        return {};

    std::vector<std::filesystem::path> result;
    for( long i = 0, e = MDQueryGetResultCount(query.get()); i < e; ++i ) {
        const MDItemRef item = static_cast<MDItemRef>(const_cast<void *>(MDQueryGetResultAtIndex(query.get(), i)));
        const base::CFPtr<CFStringRef> item_path =
            base::CFPtr<CFStringRef>::adopt(static_cast<CFStringRef>(MDItemCopyAttribute(item, kMDItemPath)));
        if( item_path ) {
            result.emplace_back(base::CFStringGetUTF8StdString(item_path.get()));
        }
    }

    return result;
}

std::vector<Tags::Tag> Tags::GatherAllItemsTags() noexcept
{
    const std::vector<std::filesystem::path> files = GatherAllItemsWithTags();
    std::vector<std::vector<Tag>> files_tags(files.size());

    // Read all the tags in multiple threads
    pstld::transform(files.begin(),
                     files.end(),
                     files_tags.begin(),
                     [](const std::filesystem::path &_path) -> std::vector<Tag> { return ReadTags(_path); });

    // And the consolidate them in a single dictionary
    ankerl::unordered_dense::set<Tags::Tag> tags;
    for( const auto &file_tags : files_tags ) {
        for( auto &file_tag : file_tags )
            tags.emplace(file_tag);
    }

    std::vector<Tag> res{tags.begin(), tags.end()};
    std::ranges::sort(res, [](const Tag &_lhs, const Tag &_rhs) {
        const auto &ll = _lhs.Label();
        const auto &rl = _rhs.Label();
        if( ll != rl )
            return ll < rl;
        return _lhs.Color() < _rhs.Color();
    });
    return res;
}

void Tags::ChangeColorOfAllItemsWithTag(std::string_view _tag, Color _color) noexcept
{
    const std::vector<std::filesystem::path> paths = GatherAllItemsWithTag(_tag);
    auto change = [_tag, _color](const std::filesystem::path &_path) {
        if( const int fd = open(_path.c_str(), O_RDONLY | O_NONBLOCK); fd >= 0 ) {
            if( auto tags = ReadTags(fd); !tags.empty() ) {
                for( auto &tag : tags ) {
                    if( tag.Label() == _tag ) {
                        tag = Tag{&tag.Label(), _color};
                        break;
                    }
                }
                WriteTags(fd, tags);
            }
            close(fd);
        }
    };
    pstld::for_each(paths.begin(), paths.end(), change);
}

void Tags::ChangeLabelOfAllItemsWithTag(std::string_view _tag, std::string_view _new_name) noexcept
{
    if( _new_name == _tag || _new_name.empty() )
        return;
    const std::string *const internalized = Tags::Tag::Internalize(_new_name);
    const std::vector<std::filesystem::path> paths = GatherAllItemsWithTag(_tag);
    auto change = [_tag, internalized](const std::filesystem::path &_path) {
        if( const int fd = open(_path.c_str(), O_RDONLY | O_NONBLOCK); fd >= 0 ) {
            if( auto tags = ReadTags(fd); !tags.empty() ) {
                for( auto &tag : tags ) {
                    if( tag.Label() == _tag ) {
                        tag = Tag{internalized, tag.Color()};
                        break;
                    }
                }
                // TODO: this currently allows to end up with duplicated labels...
                WriteTags(fd, tags);
            }
            close(fd);
        }
    };
    pstld::for_each(paths.begin(), paths.end(), change);
}

bool Tags::AddTag(const std::filesystem::path &_path, const Tag &_new_tag) noexcept
{
    const int fd = open(_path.c_str(), O_RDONLY | O_NONBLOCK);
    if( fd < 0 )
        return false;
    auto cleanup = at_scope_end([fd] { close(fd); });

    auto tags = ReadTags(fd);
    if( std::ranges::find_if(tags, [&](const Tag &_tag) { return _tag == _new_tag; }) != tags.end() ) {
        return true; // an exact tag is already present in this item, so there's nothing to do
    }

    if( auto it = std::ranges::find_if(tags, [&](const Tag &_tag) { return _tag.Label() == _new_tag.Label(); });
        it != tags.end() ) {
        // there's a tag with the same name, but with a different color - override it
        *it = _new_tag;
    }
    else {
        // add a new tag at the end
        tags.push_back(_new_tag);
    }

    return WriteTags(fd, tags);
}

bool Tags::RemoveTag(const std::filesystem::path &_path, std::string_view _label) noexcept
{
    const int fd = open(_path.c_str(), O_RDONLY | O_NONBLOCK);
    if( fd < 0 )
        return false;
    auto cleanup = at_scope_end([fd] { close(fd); });
    auto tags = ReadTags(fd);
    auto it = std::ranges::find_if(tags, [_label](const Tag &_tag) { return _tag.Label() == _label; });
    if( it == tags.end() )
        return true; // nothing to do - there's no tag with this label in the fs item
    tags.erase(it);
    return WriteTags(fd, tags);
}

void Tags::RemoveTagFromAllItems(std::string_view _tag) noexcept
{
    const std::vector<std::filesystem::path> paths = GatherAllItemsWithTag(_tag);
    auto change = [_tag](const std::filesystem::path &_path) { RemoveTag(_path, _tag); };
    pstld::for_each(paths.begin(), paths.end(), change);
}

Tags::Tag::Tag(const std::string *const _label, const Tags::Color _color) noexcept
    : m_TaggedPtr{
          reinterpret_cast<const std::string *>(reinterpret_cast<const char *>(_label) + std::to_underlying(_color))}
{
    assert(_label != nullptr);
    assert(std::to_underlying(_color) < 8);
    assert((reinterpret_cast<uint64_t>(_label) & 0x7) == 0);
}

const std::string &Tags::Tag::Label() const noexcept
{
    return *reinterpret_cast<const std::string *>(reinterpret_cast<const char *>(m_TaggedPtr) -
                                                  (reinterpret_cast<uint64_t>(m_TaggedPtr) & 0x7));
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

const std::string *Tags::Tag::Internalize(std::string_view _label) noexcept
{
    return InternalizeString(_label);
}

} // namespace nc::utility
