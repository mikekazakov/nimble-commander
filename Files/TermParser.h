//
//  TermParser.h
//  TermPlays
//
//  Created by Michael G. Kazakov on 17.11.13.
//  Copyright (c) 2013 Michael G. Kazakov. All rights reserved.
//

#pragma once

class TermScreen;
class TermTask;


// http://ascii-table.com/ansi-escape-sequences.php
// http://en.wikipedia.org/wiki/ANSI_escape_code

class TermParser
{
public:
    enum ResulFlags{
        Result_ChangedTitle = 0x0001
    };
    
    
    
    TermParser(TermScreen *_scr, TermTask *_task);
    
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
    static const int        m_UniCharsStockSize = 16384;
    static const int        m_TitleMaxLen = 1024;
    static const unsigned char m_DefaultColor = 0x07;
    
    // data and linked objects
    TermScreen             *m_Scr;
    TermTask               *m_Task;
    int                     m_EscState;
    int                     m_Params[m_ParamsSize];
    int                     m_ParamsCnt;
    int                     m_UniChar;
    int                     m_UTFCount;
    int                     m_UniCharsStockLen;
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
        unsigned char       color;
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
    unsigned short          m_UniCharsStock[m_UniCharsStockSize];
    char                    m_Title[m_TitleMaxLen];
    
    // methods
    void SetTranslate(unsigned char _charset);
    void Reset();
    void CSI_n_A();
    void CSI_n_B();
    void CSI_n_C();
    void CSI_n_d();
    void CSI_n_D();
    void CSI_n_G();
    void CSI_n_H();
    void CSI_n_J();
    void CSI_n_K();
    void CSI_n_L();
    void CSI_n_m();
    void CSI_n_P();
    void CSI_n_X();
    void CSI_n_r();
    void CSI_n_M();
    void CSI_n_At();
    void CSI_n_S();
    void CSI_n_T();
    void CSI_n_c();
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
