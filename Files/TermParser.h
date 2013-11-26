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
    TermParser(TermScreen *_scr, TermTask *_task);
    
    void EatByte(unsigned char _byte);
    void Flush();
    
    
    void ProcessKeyDown(NSEvent *_event);
    
private:
    TermScreen *m_Scr;
    TermTask   *m_Task;
    
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
    
    int m_EscState;
  
    enum {
        MaxParams = 16
    };
    int m_Params[MaxParams];
    int m_ParamsCnt;
    bool m_ParsingParamNow;
    bool m_QuestionFlag;

    int m_UniChar;
    int m_UTFCount;
    unsigned short m_UniCharsStock[16384];
    int m_UniCharsStockLen;
    
    const unsigned short    *m_TranslateMap;
    
    struct{
        unsigned char         color;
        int                   g0_charset;
        int                   g1_charset;
        int                   charset_no;
        unsigned char         intensity; // can be 0 or 1 now
        bool                  underline;
        int                   x; // used only for save&restore purposes
        int                   y; // used only for save&restore purposes
    } m_State[2]; // [0] - current, [1] - saved
    
    


    
    unsigned char           m_DefaultColor;


    
    static const int        m_TitleMaxLen = 1024;
    char                    m_Title[m_TitleMaxLen];
    int                     m_TitleLen;
    int                     m_TitleType;
    
    int                     m_Top;    // see DECSTBM  [
    int                     m_Bottom; //              )
    bool                    m_LineAbs; // if true - then y coordinates treats from the first line, otherwise from m_Top
    
    void SetTranslate(int _charset);
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
    void CSI_n_m();
    void CSI_n_P();
    void CSI_n_X();
    void CSI_n_r();
    void CSI_DEC_PMS(bool _on);

    void ESC_RI();
    
    void EscSave();
    void EscRestore();
    
    void SetDefaultAttrs();
    void UpdateAttrs();
    
    void DoGoTo(int _x, int _y); // translates _y when m_LineAbs is false.
                                 // on cases when _y stay unchanged it's not necessary to call it
};


/*
 enum { ESnormal, ESesc, ESsquare, ESgetpars, ESgotpars, ESfunckey,
 EShash, ESsetG0, ESsetG1, ESpercent, ESignore, ESnonstd,
 ESpalette, EStitle_semi, EStitle_buf } ESstate;
 int vc_state;
 
 
 - initWithTerminalScreen: (id<TerminalScreen>)ats  width: (int)w  height: (int)h;
 -(void) processByte: (unsigned char)c;
 -(void) setTerminalScreenWidth: (int)w height: (int)h;
 -(void) handleKeyEvent: (NSEvent *)e;
 -(void) sendString: (NSString *)str;
*/