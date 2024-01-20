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
static constexpr const char *g_MDItemUserTags = "com.apple.metadata:_kMDItemUserTags";
static constexpr const char *g_FinderInfo = "com.apple.FinderInfo";
[[clang::no_destroy]] static const std::string g_LabelGray = "Gray";
[[clang::no_destroy]] static const std::string g_LabelGreen = "Green";
[[clang::no_destroy]] static const std::string g_LabelPurple = "Purple";
[[clang::no_destroy]] static const std::string g_LabelBlue = "Blue";
[[clang::no_destroy]] static const std::string g_LabelYellow = "Yellow";
[[clang::no_destroy]] static const std::string g_LabelRed = "Red";
[[clang::no_destroy]] static const std::string g_LabelOrange = "Orange";

// Run this script to rebuild the table:
// for i in {0..7}; do key="TG_COLOR_$i"; find /System/Library/CoreServices/Finder.app/Contents/Resources -name
// "Localizable.strings" -exec /usr/libexec/PlistBuddy -c "Print :$key" {} \; | sed -n "s/\(.*\)/{\"&\", $i},/p"; done
[[clang::no_destroy]] static const robin_hood::unordered_flat_map<std::string, uint8_t> g_LocalizedToColors{
    {"Ohne Farbe", 0},
    {"ללא צבע", 0},
    {"No Colour", 0},
    {"لا يوجد لون", 0},
    {"Κανένα χρώμα", 0},
    {"カラーなし", 0},
    {"No Color", 0},
    {"Немає кольору", 0},
    {"Sin color", 0},
    {"无颜色", 0},
    {"Sin color", 0},
    {"Nenhuma Cor", 0},
    {"Ingen farve", 0},
    {"Nessun colore", 0},
    {"Žiadna farba", 0},
    {"Nenhuma cor", 0},
    {"Tiada Warna", 0},
    {"Ingen färg", 0},
    {"Žádná barva", 0},
    {"색상 없음", 0},
    {"Ingen farge", 0},
    {"Nincs szín", 0},
    {"沒有顏色", 0},
    {"Renk Yok", 0},
    {"Brak koloru", 0},
    {"沒有顏色", 0},
    {"No Colour", 0},
    {"Không có màu", 0},
    {"Без цвета", 0},
    {"Aucune couleur", 0},
    {"Aucune couleur", 0},
    {"Ei väriä", 0},
    {"Tidak Ada Warna", 0},
    {"Geen kleur", 0},
    {"ไม่มีสี", 0},
    {"Nicio culoare", 0},
    {"Bez boje", 0},
    {"कोई रंग नहीं", 0},
    {"Cap color", 0},
    {"Grau", 1},
    {"אפור", 1},
    {"Grey", 1},
    {"رمادي", 1},
    {"Γκρι", 1},
    {"グレイ", 1},
    {"Gray", 1},
    {"Сірий", 1},
    {"Gris", 1},
    {"灰色", 1},
    {"Gris", 1},
    {"Cinza", 1},
    {"Grå", 1},
    {"Grigio", 1},
    {"Sivá", 1},
    {"Cinzento", 1},
    {"Kelabu", 1},
    {"Grå", 1},
    {"Šedá", 1},
    {"회색", 1},
    {"Grå", 1},
    {"Szürke", 1},
    {"灰色", 1},
    {"Gri", 1},
    {"Szary", 1},
    {"灰色", 1},
    {"Grey", 1},
    {"Xám", 1},
    {"Серый", 1},
    {"Gris", 1},
    {"Gris", 1},
    {"Harmaa", 1},
    {"Abu-Abu", 1},
    {"Grijs", 1},
    {"สีเทา", 1},
    {"Gri", 1},
    {"Siva", 1},
    {"धूसर", 1},
    {"Grisa", 1},
    {"Grün", 2},
    {"ירוק", 2},
    {"Green", 2},
    {"أخضر", 2},
    {"Πράσινο", 2},
    {"グリーン", 2},
    {"Green", 2},
    {"Зелений", 2},
    {"Verde", 2},
    {"绿色", 2},
    {"Verde", 2},
    {"Verde", 2},
    {"Grøn", 2},
    {"Verde", 2},
    {"Zelená", 2},
    {"Verde", 2},
    {"Hijau", 2},
    {"Grön", 2},
    {"Zelená", 2},
    {"초록색", 2},
    {"Grønn", 2},
    {"Zöld", 2},
    {"綠色", 2},
    {"Yeşil", 2},
    {"Zielony", 2},
    {"綠色", 2},
    {"Green", 2},
    {"Lục", 2},
    {"Зеленый", 2},
    {"Vert", 2},
    {"Vert", 2},
    {"Vihreä", 2},
    {"Hijau", 2},
    {"Groen", 2},
    {"สีเขียว", 2},
    {"Verde", 2},
    {"Zelena", 2},
    {"हरा", 2},
    {"Verda", 2},
    {"Lila", 3},
    {"סגול", 3},
    {"Purple", 3},
    {"أرجواني", 3},
    {"Μοβ", 3},
    {"パープル", 3},
    {"Purple", 3},
    {"Бузковий", 3},
    {"Morado", 3},
    {"紫色", 3},
    {"Morado", 3},
    {"Roxo", 3},
    {"Lilla", 3},
    {"Viola", 3},
    {"Fialová", 3},
    {"Roxo", 3},
    {"Ungu", 3},
    {"Lila", 3},
    {"Fialová", 3},
    {"보라색", 3},
    {"Lilla", 3},
    {"Bíbor", 3},
    {"紫色", 3},
    {"Mor", 3},
    {"Purpurowy", 3},
    {"紫色", 3},
    {"Purple", 3},
    {"Tía", 3},
    {"Лиловый", 3},
    {"Violet", 3},
    {"Violet", 3},
    {"Violetti", 3},
    {"Ungu", 3},
    {"Paars", 3},
    {"สีม่วง", 3},
    {"Mov", 3},
    {"Ljubičasta", 3},
    {"जामुनी", 3},
    {"Morada", 3},
    {"Blau", 4},
    {"כחול", 4},
    {"Blue", 4},
    {"أزرق", 4},
    {"Μπλε", 4},
    {"ブルー", 4},
    {"Blue", 4},
    {"Синій", 4},
    {"Azul", 4},
    {"蓝色", 4},
    {"Azul", 4},
    {"Azul", 4},
    {"Blå", 4},
    {"Blu", 4},
    {"Modrá", 4},
    {"Azul", 4},
    {"Biru", 4},
    {"Blå", 4},
    {"Modrá", 4},
    {"파란색", 4},
    {"Blå", 4},
    {"Kék", 4},
    {"藍色", 4},
    {"Mavi", 4},
    {"Niebieski", 4},
    {"藍色", 4},
    {"Blue", 4},
    {"Lam", 4},
    {"Синий", 4},
    {"Bleu", 4},
    {"Bleu", 4},
    {"Sininen", 4},
    {"Biru", 4},
    {"Blauw", 4},
    {"สีน้ำเงิน", 4},
    {"Albastru", 4},
    {"Plava", 4},
    {"नीला", 4},
    {"Blava", 4},
    {"Gelb", 5},
    {"צהוב", 5},
    {"Yellow", 5},
    {"أصفر", 5},
    {"Κίτρινο", 5},
    {"イエロー", 5},
    {"Yellow", 5},
    {"Жовтий", 5},
    {"Amarillo", 5},
    {"黄色", 5},
    {"Amarillo", 5},
    {"Amarelo", 5},
    {"Gul", 5},
    {"Giallo", 5},
    {"Žltá", 5},
    {"Amarelo", 5},
    {"Kuning", 5},
    {"Gul", 5},
    {"Žlutá", 5},
    {"노란색", 5},
    {"Gul", 5},
    {"Sárga", 5},
    {"黃色", 5},
    {"Sarı", 5},
    {"Żółty", 5},
    {"黃色", 5},
    {"Yellow", 5},
    {"Vàng", 5},
    {"Желтый", 5},
    {"Jaune", 5},
    {"Jaune", 5},
    {"Keltainen", 5},
    {"Kuning", 5},
    {"Geel", 5},
    {"สีเหลือง", 5},
    {"Galben", 5},
    {"Žuta", 5},
    {"पीला", 5},
    {"Groga", 5},
    {"Rot", 6},
    {"אדום", 6},
    {"Red", 6},
    {"أحمر", 6},
    {"Κόκκινο", 6},
    {"レッド", 6},
    {"Red", 6},
    {"Червоний", 6},
    {"Rojo", 6},
    {"红色", 6},
    {"Rojo", 6},
    {"Vermelho", 6},
    {"Rød", 6},
    {"Rosso", 6},
    {"Červená", 6},
    {"Vermelho", 6},
    {"Merah", 6},
    {"Röd", 6},
    {"Červená", 6},
    {"빨간색", 6},
    {"Rød", 6},
    {"Piros", 6},
    {"紅色", 6},
    {"Kırmızı", 6},
    {"Czerwony", 6},
    {"紅色", 6},
    {"Red", 6},
    {"Đỏ", 6},
    {"Красный", 6},
    {"Rouge", 6},
    {"Rouge", 6},
    {"Punainen", 6},
    {"Merah", 6},
    {"Rood", 6},
    {"สีแดง", 6},
    {"Roșu", 6},
    {"Crvena", 6},
    {"लाल", 6},
    {"Vermella", 6},
    {"Orange", 7},
    {"כתום", 7},
    {"Orange", 7},
    {"برتقالي", 7},
    {"Πορτοκαλί", 7},
    {"オレンジ", 7},
    {"Orange", 7},
    {"Оранжевий", 7},
    {"Naranja", 7},
    {"橙色", 7},
    {"Naranja", 7},
    {"Laranja", 7},
    {"Orange", 7},
    {"Arancione", 7},
    {"Oranžová", 7},
    {"Laranja", 7},
    {"Jingga", 7},
    {"Orange", 7},
    {"Oranžová", 7},
    {"주황색", 7},
    {"Oransje", 7},
    {"Narancs", 7},
    {"橙色", 7},
    {"Turuncu", 7},
    {"Pomarańczowy", 7},
    {"橙色", 7},
    {"Orange", 7},
    {"Cam", 7},
    {"Оранжевый", 7},
    {"Orange", 7},
    {"Orange", 7},
    {"Oranssi", 7},
    {"Oranye", 7},
    {"Oranje", 7},
    {"สีส้ม", 7},
    {"Portocaliu", 7},
    {"Narančasta", 7},
    {"नारंगी", 7},
    {"Taronja", 7},
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

    std::optional<Tags::Color> color;
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
        auto it = g_LocalizedToColors.find(*label);
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
    }
    return {};
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
        memmem(buf.data(), res, g_MDItemUserTags, std::string_view{g_MDItemUserTags}.length()) != nullptr;
    if( has_usertags ) {
        auto tags = ReadMDItemUserTags(_fd);
        if( !tags.empty() )
            return tags;
    }

    // 2nd - try FinderInfo
    const bool has_finfo = memmem(buf.data(), res, g_FinderInfo, std::string_view{g_FinderInfo}.length()) != nullptr;
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
