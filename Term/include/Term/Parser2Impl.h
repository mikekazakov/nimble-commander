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
    
    struct CSIParamsScanner;    
    
    enum class EscState{
        Text = 0,
        Control = 1,
        Esc = 2,
        OSC = 3,
        CSI = 4
    };

    Parser2Impl( const Params& _params = {} );
    ~Parser2Impl() override;    
    std::vector<input::Command> Parse( Bytes _to_parse ) override;
    
    EscState GetEscState() const noexcept;
private:
    using Me = Parser2Impl;
    
    void SwitchTo(EscState _state);
    void Reset();
    void EatByte( unsigned char _byte );
    void FlushText();
    void ConsumeNextUTF8TextChar( unsigned char _byte );
    void LogMissedEscChar( unsigned char _c );
    void LogMissedOSCRequest( unsigned _ps, std::string_view _pt );
    void LogMissedCSIRequest( std::string_view _request );
    
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
    bool SSOSCConsumeControl(unsigned char _byte) noexcept;
    void SSOSCSubmit() noexcept;
    void SSOSCDiscard() noexcept;

    void SSCSIEnter() noexcept;
    void SSCSIExit() noexcept;
    bool SSCSIConsume(unsigned char _byte) noexcept;
    void SSCSISubmit() noexcept;
    
    void LF() noexcept;
    void HT() noexcept;
    void CR() noexcept;
    void BS() noexcept;
    void BEL() noexcept;
    void RI() noexcept;
    void RIS() noexcept;
    void DECSC() noexcept;
    void DECRC() noexcept;
    void DECALN() noexcept;
    void CSI_A() noexcept;
    void CSI_B() noexcept;
    void CSI_C() noexcept;
    void CSI_D() noexcept;
    void CSI_E() noexcept;
    void CSI_F() noexcept;
    void CSI_G() noexcept;
    void CSI_H() noexcept;
    void CSI_I() noexcept;
    void CSI_J() noexcept;
    void CSI_K() noexcept;
    void CSI_L() noexcept;
    void CSI_M() noexcept;
    void CSI_P() noexcept;
    void CSI_S() noexcept;
    void CSI_T() noexcept;
    void CSI_X() noexcept;
    void CSI_Z() noexcept;
    void CSI_a() noexcept;
    void CSI_b() noexcept;
    void CSI_c() noexcept;
    void CSI_d() noexcept;
    void CSI_e() noexcept;
    void CSI_f() noexcept;
    void CSI_hl() noexcept;
    void CSI_n() noexcept;
    void CSI_Accent() noexcept;
    
    constexpr static struct SubStates {
        void (Me::*enter)() noexcept;
        void (Me::*exit)() noexcept;
        bool (Me::*consume)(unsigned char _byte) noexcept;    
    } m_SubStates[5] = {
        { &Me::SSTextEnter, &Me::SSTextExit, &Me::SSTextConsume },
        { &Me::SSControlEnter, &Me::SSControlExit, &Me::SSControlConsume },
        { &Me::SSEscEnter, &Me::SSEscExit, &Me::SSEscConsume },
        { &Me::SSOSCEnter, &Me::SSOSCExit, &Me::SSOSCConsume },
        { &Me::SSCSIEnter, &Me::SSCSIExit, &Me::SSCSIConsume },
    };

    EscState                m_SubState = EscState::Text;
        
    struct SS_Esc {
        bool hash = false;
    } m_EscState;
    
    struct SS_Text {
        static constexpr int UTF8CharsStockSize = 16384;
        int UTF8StockLen = 0;
        std::array<char, UTF8CharsStockSize> UTF8CharsStock;
    } m_TextState;
    
    struct SS_OSC {
        std::string buffer;
        bool        got_esc = false;
    } m_OSCState;
    
    struct SS_CSI {
        std::string buffer;
    } m_CSIState;
    
    // parse output
    std::vector<input::Command> m_Output;
    
    std::function<void(std::string_view _error)> m_ErrorLog;    
};

struct Parser2Impl::CSIParamsScanner
{
    static constexpr int MaxParams = 8;
    struct Params {
        std::array<unsigned, MaxParams> values;
        int count = 0;
    };
    static Params Parse(std::string_view _csi) noexcept;
};

}
