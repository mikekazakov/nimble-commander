//
//  TermScreenBuffer.cpp
//  Files
//
//  Created by Michael G. Kazakov on 30/06/15.
//  Copyright (c) 2015 Michael G. Kazakov. All rights reserved.
//

#include "TermScreenBuffer.h"

using _ = TermScreenBuffer;

static_assert( sizeof(_::Space) == 10 , "");

_::TermScreenBuffer(unsigned _width, unsigned _height):
    m_Width(_width),
    m_Height(_height)
{
    m_OnScreenSpaces = ProduceRectangularSpaces(m_Width, m_Height);
    m_OnScreenLines.resize(m_Height);
    FixupOnScreenLinesIndeces(begin(m_OnScreenLines), end(m_OnScreenLines), m_Width);
}

unique_ptr<_::Space[]>_::ProduceRectangularSpaces(unsigned _width, unsigned _height)
{
    return make_unique<Space[]>(_width*_height);
}

void _::FixupOnScreenLinesIndeces(vector<LineMeta>::iterator _i, vector<LineMeta>::iterator _e, unsigned _width)
{
    unsigned start = 0;
    for( ;_i != _e; ++_i, start += _width) {
        _i->start_index = start;
        _i->line_length = _width;
    }
}

_::RangePair<const _::Space> _::LineFromNo(int _line_number) const
{
    if( _line_number >= 0 && _line_number < m_OnScreenLines.size() ) {
        auto &l = m_OnScreenLines[_line_number];
        assert( l.start_index + l.line_length <= m_Height*m_Width );
        
        return { &m_OnScreenSpaces[l.start_index],
                 &m_OnScreenSpaces[l.start_index + l.line_length] };
    }
    else if( _line_number < 0 && -_line_number <= m_BackScreenLines.size() ) {
        unsigned ind = unsigned((signed)m_BackScreenLines.size() + _line_number);
        auto &l = m_BackScreenLines[ind];
        assert( l.start_index + l.line_length <= m_BackScreenSpaces.size() );
        return { &m_BackScreenSpaces[l.start_index],
                 &m_BackScreenSpaces[l.start_index + l.line_length] };
    } else
        return {nullptr, nullptr};
}

_::RangePair<_::Space> _::LineFromNo(int _line_number)
{
    if( _line_number >= 0 && _line_number < m_OnScreenLines.size() ) {
        auto &l = m_OnScreenLines[_line_number];
        assert( l.start_index + l.line_length <= m_Height*m_Width );
        
        return { &m_OnScreenSpaces[l.start_index],
                 &m_OnScreenSpaces[l.start_index + l.line_length] };
    }
    else if( _line_number < 0 && -_line_number <= m_BackScreenLines.size() ) {
        unsigned ind = unsigned((signed)m_BackScreenLines.size() + _line_number);
        auto &l = m_BackScreenLines[ind];
        assert( l.start_index + l.line_length <= m_BackScreenSpaces.size() );
        return { &m_BackScreenSpaces[l.start_index],
                 &m_BackScreenSpaces[l.start_index + l.line_length] };
    }
    else
        return {nullptr, nullptr};
}

_::LineMeta *_::MetaFromLineNo( int _line_number )
{
    if( _line_number >= 0 && _line_number < m_OnScreenLines.size() )
        return &m_OnScreenLines[_line_number];
    else if( _line_number < 0 && -_line_number <= m_BackScreenLines.size() ) {
        unsigned ind = unsigned((signed)m_BackScreenLines.size() + _line_number);
        return &m_BackScreenLines[ind];
    }
    else
        return nullptr;
}

const _::LineMeta *_::MetaFromLineNo( int _line_number ) const
{
    if( _line_number >= 0 && _line_number < m_OnScreenLines.size() )
        return &m_OnScreenLines[_line_number];
    else if( _line_number < 0 && -_line_number <= m_BackScreenLines.size() ) {
        unsigned ind = unsigned((signed)m_BackScreenLines.size() + _line_number);
        return &m_BackScreenLines[ind];
    }
    else
        return nullptr;
}

string _::DumpScreenAsANSI() const
{
    string result;
    for( auto &l:m_OnScreenLines )
        for(auto *i = &m_OnScreenSpaces[l.start_index], *e = i + l.line_length; i != e; ++i)
            result += ( ( i->l >= 32 && i->l <= 127 ) ? (char)i->l : ' ');
    return result;
}

bool _::LineWrapped(int _line_number) const
{
    if(auto l = MetaFromLineNo(_line_number))
        return l->is_wrapped;
    return false;
}

void _::SetLineWrapped(int _line_number, bool _wrapped)
{
    if(auto l = MetaFromLineNo(_line_number))
        l->is_wrapped = _wrapped;
}

_::Space _::EraseChar() const
{
    return m_EraseChar;
}

void _::SetEraseChar(Space _ch)
{
    m_EraseChar = _ch;
}

_::Space _::DefaultEraseChar()
{
    Space sp;
    sp.l = 0;
    sp.c1 = 0;
    sp.c2 = 0;
    sp.foreground = TermScreenColors::Default;
    sp.background = TermScreenColors::Default;
    sp.intensity = 0;
    sp.underline = 0;
    sp.reverse   = 0;
    return sp;
}

void _::ResizeScreen(int _new_sx, int _new_sy)
{
    
    
}

void _::FeedBackscreen( const Space* _from, const Space* _to, bool _wrapped )
{
    // TODO: trimming and empty lines ?
    while( _from < _to ) {
        unsigned line_len = min( m_Width, unsigned(_to - _from) );
        
        m_BackScreenLines.emplace_back();
        m_BackScreenLines.back().start_index = (unsigned)m_BackScreenSpaces.size();
        m_BackScreenLines.back().line_length = line_len;
        m_BackScreenLines.back().is_wrapped = _wrapped ? true : (m_Width < _to - _from);
        m_BackScreenSpaces.insert(end(m_BackScreenSpaces),
                                  _from,
                                  _from + line_len);

        _from += line_len;
    }
}

vector<vector<_::Space>> _::ComposeContinuousLines(int _from, int _to) const
{
    vector<vector<_::Space>> lines;

    for(bool continue_prev = false; _from < _to; ++_from) {
        auto source = LineFromNo(_from);
        if(!source)
            throw out_of_range("invalid bounds in TermScreen::Buffer::ComposeContinuousLines");
        
        if(!continue_prev)
            lines.emplace_back();
        auto &current = lines.back();
        
        current.insert(end(current), begin(source), end(source));
        continue_prev = LineWrapped(_from);
    }
    
    return lines;
}

_::Snapshot::Snapshot(unsigned _w, unsigned _h):
    width(_w),
    height(_h),
    chars(make_unique<Space[]>( _w*_h))
{
}

void _::MakeSnapshot()
{
    if( !m_Snapshot || m_Snapshot->width != m_Width || m_Snapshot->height != m_Height )
        m_Snapshot = make_unique<Snapshot>( m_Width, m_Height );
    copy_n( m_OnScreenSpaces.get(), m_Width*m_Height, m_Snapshot->chars.get() );
}

void _::RevertToSnapshot()
{
    if( !HasSnapshot() )
        return;
    
    if( m_Height == m_Snapshot->height && m_Width == m_Snapshot->width ) {
        copy_n( m_Snapshot->chars.get(), m_Width*m_Height, m_OnScreenSpaces.get() );
    }
    else {
        // TODO
    }
}

void _::DropSnapshot()
{
    m_Snapshot.reset();
}
