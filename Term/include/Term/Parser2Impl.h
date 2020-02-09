// Copyright (C) 2020 Michael Kazakov. Subject to GNU General Public License version 3.
#include "Parser2.h"

#include <array>

namespace nc::term {

class Parser2Impl : public Parser2
{
public: 
    using Parser2::Bytes;
    
    enum class EscState{
        Normal,
        Esc,
        LeftBr,
        RightBr,
        ProcParams,
        GotParams,
        SetG0,
        SetG1,
        TitleSemicolon,
        TitleBuf
    };

    Parser2Impl();
    ~Parser2Impl() override;    
    std::vector<input::Command> Parse( Bytes _to_parse ) override;
    
    EscState GetEscState() const noexcept;
private:

    static constexpr int UTF16CharsStockSize = 16384;    
    
    void EatByte( unsigned char _byte );
    void FlushText();
    void ConsumeNextUTF8TextChar( unsigned char _byte );
    void LF();
    void HT();
    void CR();
    void BS();
    void BEL();
    
    // short state description first
    EscState                m_EscState = EscState::Normal;
    size_t                  m_UTF16CharsStockLen = 0; // number of characters in m_UTF16CharsStock
    uint32_t                m_UTF32Char = 0; // unicode character being parsed
    int                     m_UTF8Count = 0; // number of expected code units left to consume
    const unsigned short   *m_TranslateMap = nullptr;

//    // beefy data next
    std::array<uint16_t, UTF16CharsStockSize> m_UTF16CharsStock;
  
    // parse output
    std::vector<input::Command> m_Output;
};


}


//    static constexpr int        m_ParamsSize = 16;
    
