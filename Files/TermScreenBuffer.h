//
//  TermScreenBuffer.h
//  Files
//
//  Created by Michael G. Kazakov on 05/07/15.
//  Copyright (c) 2015 Michael G. Kazakov. All rights reserved.
//

#pragma once

#include "TermScreen.h"

// need:
// - backscreen
// - screenshots - saving / restoring
// - resizing
class TermScreen::Buffer
{
public:
    using Space = TermScreen::Space;
    
    Buffer(unsigned _width, unsigned _height);
    
    inline unsigned Width()  const { return m_Width;  }
    inline unsigned Height() const { return m_Height; }
    inline unsigned BackScreenLines() const { return (unsigned)m_BackScreenLines.size(); }
    
    // negative _line_number means backscreen, zero and positive - current screen
    // backscreen: [-BackScreenLines(), -1]
    // -BackScreenLines() is the oldest backscreen line
    // -1 is the last (most recent) backscreen line
    // return an iterator pair [i,e)
    // on invalid input parameters return [nullptr,nullptr)
    pair<const Space*, const Space*> LineFromNo(int _line_number) const;
    pair<Space*, Space*> LineFromNo(int _line_number);
    
    void ResizeScreen(int _new_sx, int _new_sy);
    
    void FeedBackscreen( const Space* _from, const Space* _to, bool _wrapped );
    
    bool LineWrapped(int _line_number) const;
    void SetLineWrapped(int _line_number, bool _wrapped);
    
    Space EraseChar() const;
    void SetEraseChar(Space _ch);
    static Space DefaultEraseChar();
    
    // use for diagnose and test purposes only
    string DumpScreenAsANSI() const;
    
private:
    struct LineMeta
    {
        unsigned start_index = 0;
        unsigned line_length = 0;
        bool is_wrapped = false;
    };
    
    LineMeta *MetaFromLineNo( int _line_number );
    const LineMeta *MetaFromLineNo( int _line_number ) const;
    
    static void FixupOnScreenLinesIndeces(vector<LineMeta>::iterator _i, vector<LineMeta>::iterator _e, unsigned _width);
    static unique_ptr<Space[]> ProduceRectangularSpaces(unsigned _width, unsigned _height);
    vector<vector<Space>> ComposeContinuousLines(int _from, int _to) const; // [_from, _to), _from is less than _to
    
    
    unsigned            m_Width    = 0; // onscreen and backscreen width
    unsigned            m_Height   = 0; // onscreen height, backscreen has arbitrary height
    vector<LineMeta>    m_OnScreenLines;
    vector<LineMeta>    m_BackScreenLines;
    unique_ptr<Space[]> m_OnScreenSpaces; // rebuilt on screeen size change
    vector<Space>       m_BackScreenSpaces; // will be growing
    
    Space               m_EraseChar = DefaultEraseChar();
};

inline const TermScreen::Buffer::Space*
begin( const pair<const TermScreen::Buffer::Space*, const TermScreen::Buffer::Space*> &_p )
{ return _p.first; }

inline TermScreen::Buffer::Space*
begin( const pair<TermScreen::Buffer::Space*, TermScreen::Buffer::Space*> &_p )
{ return _p.first; }

inline const TermScreen::Buffer::Space*
end( const pair<const TermScreen::Buffer::Space*, const TermScreen::Buffer::Space*> &_p )
{ return _p.second; }

inline TermScreen::Buffer::Space*
end( const pair<TermScreen::Buffer::Space*, TermScreen::Buffer::Space*> &_p )
{ return _p.second; }
