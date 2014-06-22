//
//  TermParser.h
//  TermPlays
//
//  Created by Michael G. Kazakov on 17.11.13.
//  Copyright (c) 2013 Michael G. Kazakov. All rights reserved.
//

#pragma once

class TermScreen;

// http://ascii-table.com/ansi-escape-sequences.php
// http://en.wikipedia.org/wiki/ANSI_escape_code

class TermParser
{
public:
    enum ResulFlags{
        Result_ChangedTitle = 0x0001
    };
    
    
    
    TermParser(TermScreen *_scr, void (^_task_input)(const void* _d, int _sz));
    
//    inline void SetOnChildOutput(void (^_)(const void* _d, int _sz)) { m_OnChildOutput = _; };
    
    void EatByte(unsigned char _byte, int &_result_flags);
    void Flush();
    void Resized();
    
    void ProcessKeyDown(NSEvent *_event);
    
private:
    // enumerations and constants
    enum EState{
        S_Normal,
        S_Esc,
        S_LeftBr,
        S_RightBr,
        S_ProcParams,
        S_GotParams,
        S_SetG0,
        S_SetG1,
        S_TitleSemicolon,
        S_TitleBuf
    };
    
    static const int        m_ParamsSize = 16;
    static const int        m_UTF16CharsStockSize = 16384;
    static const int        m_TitleMaxLen = 1024;
    static const unsigned char m_DefaultColor = 0x07;
    
    // data and linked objects
    TermScreen             *m_Scr;
    void                  (^m_TaskInput)(const void* _d, int _sz);
    int                     m_EscState;
    int                     m_Params[m_ParamsSize];
    int                     m_ParamsCnt;
    uint32_t                m_UTF32Char;
    int                     m_UTF8Count;
    int                     m_UTF16CharsStockLen;
    const unsigned short   *m_TranslateMap;
    int                     m_TitleLen;
    int                     m_TitleType;
    int                     m_Height;
    int                     m_Width;
    int                     m_Top;    // see DECSTBM  [
    int                     m_Bottom; //              )
    int                     m_DECPMS_SavedCurX; // used only for DEC private modes 1048/1049
    int                     m_DECPMS_SavedCurY; // -""-
    struct{
        int                 fg_color;
        int                 bg_color;
        unsigned char       g0_charset;
        unsigned char       g1_charset;
        unsigned char       charset_no;
        bool                intensity;
        bool                underline;
        bool                reverse;
        int                 x; // used only for save&restore purposes
        int                 y; // used only for save&restore purposes
    } m_State[2]; // [0] - current, [1] - saved

    bool                    m_InsertMode;
    bool                    m_LineAbs; // if true - then y coordinates treats from the first line, otherwise from m_Top
    bool                    m_ParsingParamNow;
    bool                    m_QuestionFlag;
    
    // 'big' data comes at last
    unsigned int            m_TabStop[16];
    uint16_t                m_UTF16CharsStock[m_UTF16CharsStockSize];
    char                    m_Title[m_TitleMaxLen];
    
    // methods
    void SetTranslate(unsigned char _charset);
    void Reset();
    void CSI_A();
    void CSI_B();
    void CSI_C();
    void CSI_d();
    void CSI_D();
    void CSI_G();
    void CSI_H();
    void CSI_J();
    void CSI_K();
    void CSI_L();
    void CSI_m();
    void CSI_P();
    void CSI_X();
    void CSI_r();
    void CSI_M();
    void CSI_At();
    void CSI_S();
    void CSI_T();
    void CSI_c();
    void CSI_DEC_PMS(bool _on);
    void EscSave();
    void EscRestore();
    void HT(); // horizontal tab
    void RI(); // move/scroll window down one line
    void LF(); // line feed
    void CR(); // carriage return
    void SetDefaultAttrs();
    void UpdateAttrs();
    void DoGoTo(int _x, int _y); // translates _y when m_LineAbs is false.
                                 // on cases when _y stay unchanged it's not necessary to call it
};
