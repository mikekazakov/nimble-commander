// Copyright (C) 2024 Michael Kazakov. Subject to GNU General Public License version 3.
#pragma once

#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wnon-virtual-dtor"
#include <scintilla/ILexer.h>
#pragma clang diagnostic pop

#include <string_view>
#include <vector>
#include <span>

namespace nc::viewer::hl {

class Document : public Scintilla::IDocument
{
public:
    Document(std::string_view _text);
    virtual ~Document();

    char StyleAt(Sci_Position position) const override;

    int GetLevel(Sci_Position line) const override;

    int SetLevel(Sci_Position line, int level) override;

    int GetLineState(Sci_Position line) const override;

    int SetLineState(Sci_Position line, int state) override;

    int CodePage() const override;

    bool IsDBCSLeadByte(char ch) const override;

    int GetLineIndentation(Sci_Position line) override;

    Sci_Position LineEnd(Sci_Position line) const override;

    Sci_Position GetRelativePosition(Sci_Position positionStart, Sci_Position characterOffset) const override;

    int GetCharacterAndWidth(Sci_Position position, Sci_Position *pWidth) const override;

    int Version() const noexcept override;

    void SetErrorStatus(int status) noexcept override;

    Sci_Position Length() const noexcept override;

    void GetCharRange(char *buffer, Sci_Position position, Sci_Position lengthRetrieve) const noexcept override;

    const char *BufferPointer() noexcept override;

    Sci_Position LineFromPosition(Sci_Position pos) const noexcept override;

    Sci_Position LineStart(Sci_Position line) const noexcept override;

    void StartStyling(Sci_Position position) noexcept override;

    bool SetStyleFor(Sci_Position length, char style) noexcept override;

    bool SetStyles(Sci_Position length, const char *styles) noexcept override;

    void DecorationSetCurrentIndicator(int indicator) noexcept override;

    void DecorationFillRange(Sci_Position position, int value, Sci_Position fillLength) noexcept override;

    void ChangeLexerState(Sci_Position start, Sci_Position end) noexcept override;

private:
    std::string_view m_Text;
    std::vector<char> m_Styles;
    Sci_Position m_StylingPosition = 0;
};

} // namespace nc::viewer::hl
