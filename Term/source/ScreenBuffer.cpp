// Copyright (C) 2015-2019 Michael Kazakov. Subject to GNU General Public License version 3.
#include "ScreenBuffer.h"
#include <CoreFoundation/CoreFoundation.h>

namespace nc::term {

static_assert( sizeof(ScreenBuffer::Space) == 10 , "");

ScreenBuffer::ScreenBuffer(unsigned _width, unsigned _height):
    m_Width(_width),
    m_Height(_height)
{
    m_OnScreenSpaces = ProduceRectangularSpaces(m_Width, m_Height);
    m_OnScreenLines.resize(m_Height);
    FixupOnScreenLinesIndeces(begin(m_OnScreenLines), end(m_OnScreenLines), m_Width);
}

std::unique_ptr<ScreenBuffer::Space[]>ScreenBuffer::ProduceRectangularSpaces(unsigned _width,
                                                                             unsigned _height)
{
    return std::make_unique<Space[]>(_width*_height);
}

std::unique_ptr<ScreenBuffer::Space[]> ScreenBuffer::ProduceRectangularSpaces(unsigned _width,
                                                                              unsigned _height,
                                                                              Space _initial_char)
{
    auto p = ProduceRectangularSpaces(_width, _height);
    std::fill( &p[0], &p[_width*_height], _initial_char );
    return p;
}

void ScreenBuffer::FixupOnScreenLinesIndeces(std::vector<LineMeta>::iterator _i,
                                             std::vector<LineMeta>::iterator _e,
                                             unsigned _width)
{
    unsigned start = 0;
    for( ;_i != _e; ++_i, start += _width) {
        _i->start_index = start;
        _i->line_length = _width;
    }
}

ScreenBuffer::RangePair<const ScreenBuffer::Space> ScreenBuffer::LineFromNo(int _line_number) const
{
    if( _line_number >= 0 && _line_number < (int)m_OnScreenLines.size() ) {
        auto &l = m_OnScreenLines[_line_number];
        assert( l.start_index + l.line_length <= m_Height*m_Width );
        
        return { &m_OnScreenSpaces[l.start_index],
                 &m_OnScreenSpaces[l.start_index + l.line_length] };
    }
    else if( _line_number < 0 && -_line_number <= (int)m_BackScreenLines.size() ) {
        unsigned ind = unsigned((signed)m_BackScreenLines.size() + _line_number);
        auto &l = m_BackScreenLines[ind];
        assert( l.start_index + l.line_length <= m_BackScreenSpaces.size() );
        return { &m_BackScreenSpaces[l.start_index],
                 &m_BackScreenSpaces[l.start_index + l.line_length] };
    } else
        return {nullptr, nullptr};
}

ScreenBuffer::RangePair<ScreenBuffer::Space> ScreenBuffer::LineFromNo(int _line_number)
{
    if( _line_number >= 0 && _line_number < (int)m_OnScreenLines.size() ) {
        auto &l = m_OnScreenLines[_line_number];
        assert( l.start_index + l.line_length <= m_Height*m_Width );
        
        return { &m_OnScreenSpaces[l.start_index],
                 &m_OnScreenSpaces[l.start_index + l.line_length] };
    }
    else if( _line_number < 0 && -_line_number <= (int)m_BackScreenLines.size() ) {
        unsigned ind = unsigned((signed)m_BackScreenLines.size() + _line_number);
        auto &l = m_BackScreenLines[ind];
        assert( l.start_index + l.line_length <= m_BackScreenSpaces.size() );
        return { &m_BackScreenSpaces[l.start_index],
                 &m_BackScreenSpaces[l.start_index + l.line_length] };
    }
    else
        return {nullptr, nullptr};
}

ScreenBuffer::LineMeta *ScreenBuffer::MetaFromLineNo( int _line_number )
{
    if( _line_number >= 0 && _line_number < (int)m_OnScreenLines.size() )
        return &m_OnScreenLines[_line_number];
    else if( _line_number < 0 && -_line_number <= (int)m_BackScreenLines.size() ) {
        unsigned ind = unsigned((signed)m_BackScreenLines.size() + _line_number);
        return &m_BackScreenLines[ind];
    }
    else
        return nullptr;
}

const ScreenBuffer::LineMeta *ScreenBuffer::MetaFromLineNo( int _line_number ) const
{
    if( _line_number >= 0 && _line_number < (int)m_OnScreenLines.size() )
        return &m_OnScreenLines[_line_number];
    else if( _line_number < 0 && -_line_number <= (int)m_BackScreenLines.size() ) {
        unsigned ind = unsigned((signed)m_BackScreenLines.size() + _line_number);
        return &m_BackScreenLines[ind];
    }
    else
        return nullptr;
}

std::vector<uint32_t> ScreenBuffer::DumpUnicodeString(const ScreenPoint _begin,
                                                      const ScreenPoint _end ) const
{
    if( _begin >= _end )
        return {};
    
    std::vector<uint32_t> unicode;
    auto curr = _begin;
    while( curr < _end ) {
        auto line = LineFromNo( curr.y );
        
        if( !line ) {
            curr.y++;
            continue;
        }

        bool any_inserted = false;
        const auto chars_len = (int)OccupiedChars(line.first, line.second);
        for( ; curr.x < chars_len && curr < _end; ++curr.x ) {
            auto &sp = line.first[curr.x];
            if( sp.l == MultiCellGlyph )
                continue;
            unicode.push_back(sp.l != 0 ? sp.l : ' ');
            if(sp.c1 != 0) unicode.push_back(sp.c1);
            if(sp.c2 != 0) unicode.push_back(sp.c2);
            any_inserted = true;
        }
        
        if( curr >= _end )
            break;
        
        if( any_inserted && !LineWrapped( curr.y ) )
            unicode.push_back(0x000A);
        
        curr.y++;
        curr.x = 0;
    }
    
    return unicode;
}

std::pair<std::vector<uint16_t>, std::vector<ScreenPoint>>
    ScreenBuffer::DumpUTF16StringWithLayout(ScreenPoint _begin,
                                            ScreenPoint _end ) const
{
    if( _begin >= _end )
        return {};
    
    std::vector<uint16_t> unichars;
    std::vector<ScreenPoint> positions;
    
    auto curr = _begin;
    
    auto put = [&](uint16_t _unichar) {
        unichars.emplace_back(_unichar);
        positions.emplace_back(curr);
    };
    
    while( curr < _end ) {
        auto line = LineFromNo( curr.y );
        
        if( !line ) {
            curr.y++;
            continue;
        }

        bool any_inserted = false;
        const auto chars_len = (int)OccupiedChars(line.first, line.second);
        for( ; curr.x < chars_len && curr < _end; ++curr.x ) {
            auto &sp = line.first[curr.x];
            if( sp.l == MultiCellGlyph )
                continue;
            
            uint16_t utf16[2];
            if( CFStringGetSurrogatePairForLongCharacter(sp.l != 0 ? sp.l : ' ', utf16) ) {
                put(utf16[0]);
                put(utf16[1]);
            }
            else
                put(utf16[0]);
    
            if(sp.c1 != 0) put(sp.c1);
            if(sp.c2 != 0) put(sp.c2);
            
            any_inserted = true;
        }
        
        if( curr >= _end )
            break;
        
        if( any_inserted && !LineWrapped( curr.y ) )
            put(0x000A);
        
        curr.y++;
        curr.x = 0;
    }
    
    return {std::move(unichars), std::move(positions)};
}

std::string ScreenBuffer::DumpScreenAsANSI() const
{
    std::string result;
    for( auto &l:m_OnScreenLines )
        for(auto *i = &m_OnScreenSpaces[l.start_index], *e = i + l.line_length; i != e; ++i)
            result += ( ( i->l >= 32 && i->l <= 127 ) ? (char)i->l : ' ');
    return result;
}

std::string ScreenBuffer::DumpScreenAsANSIBreaked() const
{
    std::string result;
    for( auto &l:m_OnScreenLines ) {
        for(auto *i = &m_OnScreenSpaces[l.start_index], *e = i + l.line_length; i != e; ++i)
            result += ( ( i->l >= 32 && i->l <= 127 ) ? (char)i->l : ' ');
        result += '\r';
    }
    return result;
}

bool ScreenBuffer::LineWrapped(int _line_number) const
{
    if(auto l = MetaFromLineNo(_line_number))
        return l->is_wrapped;
    return false;
}

void ScreenBuffer::SetLineWrapped(int _line_number, bool _wrapped)
{
    if(auto l = MetaFromLineNo(_line_number))
        l->is_wrapped = _wrapped;
}

ScreenBuffer::Space ScreenBuffer::EraseChar() const
{
    return m_EraseChar;
}

void ScreenBuffer::SetEraseChar(Space _ch)
{
    m_EraseChar = _ch;
}

ScreenBuffer::Space ScreenBuffer::DefaultEraseChar()
{
    Space sp;
    sp.l = 0;
    sp.c1 = 0;
    sp.c2 = 0;
    sp.foreground = ScreenColors::Default;
    sp.background = ScreenColors::Default;
    sp.intensity = 0;
    sp.underline = 0;
    sp.reverse   = 0;
    return sp;
}

// need real ocupied size
// need "anchor" here
void ScreenBuffer::ResizeScreen(unsigned _new_sx, unsigned _new_sy, bool _merge_with_backscreen)
{
    if( _new_sx == 0 || _new_sy == 0)
        throw std::out_of_range("TermScreenBuffer::ResizeScreen - screen sizes can't be zero");

    using ConstIt = std::vector< std::tuple<std::vector<Space>, bool> >::const_iterator;
    auto fill_scr_from_declines = [=](ConstIt _i, ConstIt _e, size_t _l = 0){
        for( ; _i != _e; ++_i, ++_l ) {
            std::copy(std::begin(std::get<0>(*_i)),
                      std::end(std::get<0>(*_i)),
                      &m_OnScreenSpaces[ m_OnScreenLines[_l].start_index ] );
            m_OnScreenLines[_l].is_wrapped = std::get<1>(*_i);
        }
    };
    auto fill_bkscr_from_declines = [=](ConstIt _i,
                                        ConstIt _e){
        for( ; _i != _e; ++_i ) {
            LineMeta lm;
            lm.start_index = (int)m_BackScreenSpaces.size();
            lm.line_length = (int)std::get<0>(*_i).size();
            lm.is_wrapped = std::get<1>(*_i);
            m_BackScreenLines.emplace_back(lm);
            m_BackScreenSpaces.insert(std::end(m_BackScreenSpaces),
                                      std::begin(std::get<0>(*_i)),
                                      std::end(std::get<0>(*_i)) );
        }
    };
    
    if( _merge_with_backscreen ) {
        auto comp_lines = ComposeContinuousLines(-BackScreenLines(), Height());
        auto decomp_lines = DecomposeContinuousLines(comp_lines, _new_sx);
        
        m_BackScreenLines.clear();
        m_BackScreenSpaces.clear();
        if( decomp_lines.size() > _new_sy) {
            fill_bkscr_from_declines( begin(decomp_lines), end(decomp_lines) - _new_sy );
            
            m_OnScreenSpaces = ProduceRectangularSpaces(_new_sx, _new_sy, m_EraseChar);
            m_OnScreenLines.resize(_new_sy);
            FixupOnScreenLinesIndeces(begin(m_OnScreenLines), end(m_OnScreenLines), _new_sx);
            fill_scr_from_declines( end(decomp_lines) - _new_sy, end(decomp_lines) );
        }
        else {
            m_OnScreenSpaces = ProduceRectangularSpaces(_new_sx, _new_sy, m_EraseChar);
            m_OnScreenLines.resize(_new_sy);
            FixupOnScreenLinesIndeces(begin(m_OnScreenLines), end(m_OnScreenLines), _new_sx);
            fill_scr_from_declines( begin(decomp_lines), end(decomp_lines) );
        }
    }
    else {
        auto bkscr_decomp_lines = DecomposeContinuousLines(ComposeContinuousLines(-BackScreenLines(), 0),
                                                           _new_sx);
        m_BackScreenLines.clear();
        m_BackScreenSpaces.clear();
        fill_bkscr_from_declines( begin(bkscr_decomp_lines), end(bkscr_decomp_lines) );
        
        auto onscr_decomp_lines = DecomposeContinuousLines(ComposeContinuousLines(0, Height()),
                                                           _new_sx);
        m_OnScreenSpaces = ProduceRectangularSpaces(_new_sx, _new_sy, m_EraseChar);
        m_OnScreenLines.resize(_new_sy);
        FixupOnScreenLinesIndeces(begin(m_OnScreenLines), end(m_OnScreenLines), _new_sx);
        fill_scr_from_declines(begin(onscr_decomp_lines),
                               min(begin(onscr_decomp_lines) + _new_sy,
                               end(onscr_decomp_lines)) );
    }

    m_Width = _new_sx;
    m_Height = _new_sy;
}

void ScreenBuffer::FeedBackscreen( const Space* _from, const Space* _to, bool _wrapped )
{
    // TODO: trimming and empty lines ?
    while( _from < _to ) {
        unsigned line_len = std::min( m_Width, unsigned(_to - _from) );
        
        m_BackScreenLines.emplace_back();
        m_BackScreenLines.back().start_index = (unsigned)m_BackScreenSpaces.size();
        m_BackScreenLines.back().line_length = line_len;
        m_BackScreenLines.back().is_wrapped = _wrapped ? true : (m_Width < _to - _from);
        m_BackScreenSpaces.insert(std::end(m_BackScreenSpaces),
                                  _from,
                                  _from + line_len);

        _from += line_len;
    }
}

static inline bool IsOccupiedChar( const ScreenBuffer::Space &_s )
{
    return _s.l != 0;
}

unsigned ScreenBuffer::OccupiedChars( const RangePair<const Space> &_line )
{
    return OccupiedChars( _line.first, _line.second );
}

unsigned ScreenBuffer::OccupiedChars( const Space *_begin, const Space *_end )
{
    assert( _end >= _end );
    if( _end == _begin)
        return 0;

    unsigned len = 0;
    for( auto i = _end - 1; i >= _begin; --i ) // going backward
        if( IsOccupiedChar(*i) ) {
            len = (unsigned)(i - _begin + 1);
            break;
        }
    
    return len;
}

bool ScreenBuffer::HasOccupiedChars( const Space *_begin, const Space *_end )
{
    assert( _end >= _end );
    for( ; _begin != _end; ++_begin ) // going forward
        if( IsOccupiedChar(*_begin) )
            return true;
    return false;;
}

unsigned ScreenBuffer::OccupiedChars( int _line_no ) const
{
    if( auto l = LineFromNo(_line_no) )
        return OccupiedChars(begin(l), end(l));
    return 0;
}

bool ScreenBuffer::HasOccupiedChars( int _line_no ) const
{
    if( auto l = LineFromNo(_line_no) )
        return HasOccupiedChars(begin(l), end(l));
    return false;
}

std::vector<std::vector<ScreenBuffer::Space>>
    ScreenBuffer::ComposeContinuousLines(int _from, int _to) const
{
    std::vector<std::vector<Space>> lines;

    for( bool continue_prev = false; _from < _to; ++_from) {
        auto source = LineFromNo(_from);
        if(!source)
            throw std::out_of_range("invalid bounds in TermScreen::Buffer::ComposeContinuousLines");
        
        if(!continue_prev)
            lines.emplace_back();
        auto &current = lines.back();
        
        current.insert(end(current),
                       begin(source),
                       begin(source) + OccupiedChars(begin(source),
                                                     end(source))
                       );
        continue_prev = LineWrapped(_from);
    }
    
    return lines;
}

std::vector< std::tuple<std::vector<ScreenBuffer::Space>, bool> >
    ScreenBuffer::DecomposeContinuousLines(const std::vector<std::vector<Space>>& _src,
                                           unsigned _width )
{
    if( _width == 0) {
        auto msg = "TermScreenBuffer::DecomposeContinuousLines width can't be zero";
        throw std::invalid_argument(msg);
    }

    std::vector< std::tuple<std::vector<Space>, bool> > result;
    
    for( auto &l: _src ) {
        if( l.empty() ) // special case for CRLF-only lines
            result.emplace_back( std::make_tuple<std::vector<Space>, bool>({}, false) );

        for( size_t i = 0, e = l.size(); i < e; i += _width ) {
            auto t = std::make_tuple<std::vector<Space>, bool>({}, false);
            if( i + _width < e ) {
                std::get<0>(t).assign( begin(l) + i, begin(l) + i + _width );
                std::get<1>(t) = true;
            }
            else {
                std::get<0>(t).assign( begin(l) + i, end(l) );
            }
            result.emplace_back( move(t) );
        }
    }
    return result;
}

ScreenBuffer::Snapshot::Snapshot(unsigned _w, unsigned _h):
    width(_w),
    height(_h),
    chars(std::make_unique<Space[]>( _w*_h))
{
}

void ScreenBuffer::MakeSnapshot()
{
    if( !m_Snapshot || m_Snapshot->width != m_Width || m_Snapshot->height != m_Height )
        m_Snapshot = std::make_unique<Snapshot>( m_Width, m_Height );
    std::copy_n( m_OnScreenSpaces.get(), m_Width*m_Height, m_Snapshot->chars.get() );
}

void ScreenBuffer::RevertToSnapshot()
{
    if( !HasSnapshot() )
        return;
    
    if( m_Height == m_Snapshot->height && m_Width == m_Snapshot->width ) {
        std::copy_n( m_Snapshot->chars.get(), m_Width*m_Height, m_OnScreenSpaces.get() );
    }
    else { // TODO: anchor?
        std::fill_n( m_OnScreenSpaces.get(), m_Width*m_Height, m_EraseChar );
        for( int y = 0, e = std::min(m_Snapshot->height, m_Height); y != e; ++y ) {
            std::copy_n( m_Snapshot->chars.get() + y*m_Snapshot->width,
                        std::min(m_Snapshot->width, m_Width),
                        m_OnScreenSpaces.get() + y*m_Width);
        }
    }
}

void ScreenBuffer::DropSnapshot()
{
    m_Snapshot.reset();
}

std::optional<std::pair<int, int>> ScreenBuffer::OccupiedOnScreenLines() const
{
    int first = std::numeric_limits<int>::max(),
    last = std::numeric_limits<int>::min();
    for( int i = 0, e = Height(); i < e; ++i )
        if( HasOccupiedChars(i) ) {
            first = std::min(first, i);
            last = std::max(last, i);
        }
    
    if( first > last )
        return std::nullopt;
    
    return std::make_pair(first, last + 1);
}

}
