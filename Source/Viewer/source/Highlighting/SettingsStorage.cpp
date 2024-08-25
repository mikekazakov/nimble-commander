// Copyright (C) 2024 Michael Kazakov. Subject to GNU General Public License version 3.
#include <Viewer/Highlighting/SettingsStorage.h>

namespace nc::viewer::hl {

std::optional<std::string> DummySettingsStorage::Language(std::string_view _filename)
{
    (void)_filename;
    return {};
}

std::vector<std::string> DummySettingsStorage::List()
{
    return {};
}

std::shared_ptr<const std::string> DummySettingsStorage::Settings(std::string_view _lang)
{
    (void)_lang;

    const auto settings = R"({
        "lexer": "cpp",
        "wordlists": ["alignas alignof and and_eq asm auto bitand bitor bool break case catch char char8_t char16_t char32_t class compl concept const consteval constexpr constinit const_cast continue co_await co_return co_yield decltype default delete do double dynamic_cast else enum explicit export extern false float for friend goto if inline int long mutable namespace new noexcept not not_eq nullptr operator or or_eq private protected public register reinterpret_cast requires return short signed sizeof static static_assert static_cast struct switch template this thread_local throw true try typedef typeid typename union unsigned using virtual void volatile wchar_t while xor xor_eq"],
        "mapping": {
            "SCE_C_DEFAULT": "default",
            "SCE_C_COMMENT": "comment",
            "SCE_C_COMMENTLINE": "comment",
            "SCE_C_COMMENTDOC": "comment",
            "SCE_C_NUMBER": "number",
            "SCE_C_WORD": "keyword",
            "SCE_C_STRING": "string",
            "SCE_C_CHARACTER": "string",
            "SCE_C_UUID": "string",
            "SCE_C_PREPROCESSOR": "preprocessor",
            "SCE_C_OPERATOR": "operator",
            "SCE_C_IDENTIFIER": "identifier",
            "SCE_C_STRINGEOL": "string"
        }
    })";
    [[clang::no_destroy]] static auto ptr = std::make_shared<std::string>(settings);
    return ptr;
}

} // namespace nc::viewer::hl
