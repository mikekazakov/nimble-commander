// Copyright (C) 2020 Michael Kazakov. Subject to GNU General Public License version 3.
#include "Parser2.h"

#include <array>
#include <functional>
#include <string_view>

namespace nc::term {

class Parser2Impl : public Parser2
{
public: 
    using Parser2::Bytes;
    
    struct Params {
        std::function<void(std::string_view _error)> error_log;
    };
    
    enum class EscState{
        Text = 0,
        Control = 1,
        Esc = 2,
        OSC = 3
    };

    Parser2Impl( const Params& _params = {} );
    ~Parser2Impl() override;    
    std::vector<input::Command> Parse( Bytes _to_parse ) override;
    
    EscState GetEscState() const noexcept;
private:
    using Me = Parser2Impl;
    static constexpr int UTF16CharsStockSize = 16384;    
    
    void SwitchTo(EscState _state);
    void Reset();
    void EatByte( unsigned char _byte );
    void FlushText();
    void ConsumeNextUTF8TextChar( unsigned char _byte );
    void LogMissedEscChar( unsigned char _c );
    
    void SSTextEnter() noexcept;
    void SSTextExit() noexcept;
    bool SSTextConsume(unsigned char _byte) noexcept;

    void SSControlEnter() noexcept;
    void SSControlExit() noexcept;
    bool SSControlConsume(unsigned char _byte) noexcept;

    void SSEscEnter() noexcept;
    void SSEscExit() noexcept;
    bool SSEscConsume(unsigned char _byte) noexcept;

    void SSOSCEnter() noexcept;
    void SSOSCExit() noexcept;
    bool SSOSCConsume(unsigned char _byte) noexcept;
    void SSOSCSubmit() noexcept;
    void SSOSCDiscard() noexcept;
    
    void LF() noexcept;
    void HT() noexcept;
    void CR() noexcept;
    void BS() noexcept;
    void BEL() noexcept;
    void RI() noexcept;
    void RIS() noexcept;
    void DECSC() noexcept;
    void DECRC() noexcept;
    
    constexpr static struct SubStates {
        void (Me::*enter)() noexcept;
        void (Me::*exit)() noexcept;
        bool (Me::*consume)(unsigned char _byte) noexcept;    
    } m_SubStates[4] = {
        { &Me::SSTextEnter, &Me::SSTextExit, &Me::SSTextConsume },
        { &Me::SSControlEnter, &Me::SSControlExit, &Me::SSControlConsume },
        { &Me::SSEscEnter, &Me::SSEscExit, &Me::SSEscConsume },
        { &Me::SSOSCEnter, &Me::SSOSCExit, &Me::SSOSCConsume },
    };
        
    EscState                m_EscState = EscState::Text;
    const unsigned short   *m_TranslateMap = nullptr;    
        
    struct SS_Text {
        size_t      UTF16CharsStockLen = 0; // number of characters in m_UTF16CharsStock
        uint32_t    UTF32Char = 0; // unicode character being parsed
        int         UTF8Count = 0; // number of expected code units left to consume    
        std::array<uint16_t, UTF16CharsStockSize> UTF16CharsStock;
    } m_TextState;
    
    struct SS_OSC {
        std::string buffer;
        bool        got_esc = false;
    } m_OSCState;
    
    // parse output
    std::vector<input::Command> m_Output;
    
    std::function<void(std::string_view _error)> m_ErrorLog;    
};


}


//    static constexpr int        m_ParamsSize = 16;
    
