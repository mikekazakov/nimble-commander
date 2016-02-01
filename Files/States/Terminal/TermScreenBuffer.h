//
//  TermScreenBuffer.h
//  Files
//
//  Created by Michael G. Kazakov on 05/07/15.
//  Copyright (c) 2015 Michael G. Kazakov. All rights reserved.
//

#pragma once

struct TermScreenColors
{
    enum {
        Black       = 0,
        Red         = 1,
        Green       = 2,
        Yellow      = 3,
        Blue        = 4,
        Magenta     = 5,
        Cyan        = 6,
        White       = 7,
        BlackHi     = 8,
        RedHi       = 9,
        GreenHi     = 10,
        YellowHi    = 11,
        BlueHi      = 12,
        MagentaHi   = 13,
        CyanHi      = 14,
        WhiteHi     = 15,
        Default     = 16
    }; // need 5 bits to store this color
};

struct TermScreenPoint
{
    int x = 0;
    int y = 0;
    inline TermScreenPoint() noexcept {};
    inline TermScreenPoint(int _x, int _y) noexcept: x(_x), y(_y) {};
    inline bool operator > (const TermScreenPoint&_r) const noexcept { return (y > _r.y) || (y == _r.y && x >  _r.x); }
    inline bool operator >=(const TermScreenPoint&_r) const noexcept { return (y > _r.y) || (y == _r.y && x >= _r.x); }
    inline bool operator < (const TermScreenPoint&_r) const noexcept { return !(*this >= _r); }
    inline bool operator <=(const TermScreenPoint&_r) const noexcept { return !(*this >  _r); }
    inline bool operator ==(const TermScreenPoint&_r) const noexcept { return y == _r.y && x == _r.x; }
    inline bool operator !=(const TermScreenPoint&_r) const noexcept { return y != _r.y || x != _r.x; }
};

class TermScreenBuffer
{
public:
#pragma pack(push, 1)
    struct Space
    {
        uint32_t             l; // basic letter, may be non-bmp
        uint16_t            c1; // combining character 1. zero if no. bmp-only
        uint16_t            c2; // combining character 2. zero if no. bmp-only
        unsigned foreground :5;
        unsigned background :5;
        unsigned intensity  :1;
        unsigned underline  :1;
        unsigned reverse    :1;
    }; // 10 bytes per screen space
    static_assert( sizeof(Space) == 10, "" );
#pragma pop
    
    static const unsigned short MultiCellGlyph = 0xFFFE;    
    
    TermScreenBuffer(unsigned _width, unsigned _height);
    
    inline unsigned Width()  const { return m_Width;  }
    inline unsigned Height() const { return m_Height; }
    inline unsigned BackScreenLines() const { return (unsigned)m_BackScreenLines.size(); }
    
    // negative _line_number means backscreen, zero and positive - current screen
    // backscreen: [-BackScreenLines(), -1]
    // -BackScreenLines() is the oldest backscreen line
    // -1 is the last (most recent) backscreen line
    // return an iterator pair [i,e)
    // on invalid input parameters return [nullptr,nullptr)
    template <class T> struct RangePair : public pair<T*,T*>
    {
        using pair<T*,T*>::pair;
        operator bool() const { return this->first != nullptr && this->second != nullptr; };
    };
    RangePair<const Space> LineFromNo(int _line_number) const;
    RangePair<Space> LineFromNo(int _line_number);
    
    void ResizeScreen(unsigned _new_sx, unsigned _new_sy, bool _merge_with_backscreen );
    
    void FeedBackscreen( const Space* _from, const Space* _to, bool _wrapped );
    
    bool LineWrapped(int _line_number) const;
    void SetLineWrapped(int _line_number, bool _wrapped);
    
    Space EraseChar() const;
    void SetEraseChar(Space _ch);
    static Space DefaultEraseChar();
    
    /**
     * [1st, 2nd) lines range.
     * lines should have any non-zero symbol, including space (32).
     * if screen is absolutely clean it will return nullopt
     */
    optional<pair<int, int>> OccupiedOnScreenLines() const;
    
    vector<uint32_t> DumpUnicodeString( TermScreenPoint _begin, TermScreenPoint _end ) const;
    pair<vector<uint16_t>, vector<TermScreenPoint>> DumpUTF16StringWithLayout( TermScreenPoint _begin, TermScreenPoint _end ) const;
    
    // use for diagnose and test purposes only
    string DumpScreenAsANSI() const;
    
    inline bool HasSnapshot() const { return (bool)m_Snapshot; }
    void MakeSnapshot();
    void RevertToSnapshot();
    void DropSnapshot();
    
    static unsigned OccupiedChars( const Space *_begin, const Space *_end );
    static bool HasOccupiedChars( const Space *_begin, const Space *_end );
    unsigned OccupiedChars( int _line_no ) const;
    bool HasOccupiedChars( int _line_no ) const;
    
private:
    struct LineMeta
    {
        unsigned start_index = 0;
        unsigned line_length = 0;
        bool is_wrapped = false;
    };
    
    struct Snapshot
    {
        Snapshot(unsigned _w, unsigned _h);
        const unsigned            width;
        const unsigned            height;
        const unique_ptr<Space[]> chars;
    };
    
    LineMeta *MetaFromLineNo( int _line_number );
    const LineMeta *MetaFromLineNo( int _line_number ) const;
    
    static void FixupOnScreenLinesIndeces(vector<LineMeta>::iterator _i, vector<LineMeta>::iterator _e, unsigned _width);
    static unique_ptr<Space[]> ProduceRectangularSpaces(unsigned _width, unsigned _height);
    static unique_ptr<Space[]> ProduceRectangularSpaces(unsigned _width, unsigned _height, Space _initial_char);
    vector<vector<Space>> ComposeContinuousLines(int _from, int _to) const; // [_from, _to), _from is less than _to
    static vector< tuple<vector<Space>, bool> > DecomposeContinuousLines( const vector<vector<Space>>& _scr, unsigned _width ); // <spaces, is wrapped>
    
    
    unsigned            m_Width    = 0; // onscreen and backscreen width
    unsigned            m_Height   = 0; // onscreen height, backscreen has arbitrary height
    vector<LineMeta>    m_OnScreenLines;
    vector<LineMeta>    m_BackScreenLines;
    unique_ptr<Space[]> m_OnScreenSpaces; // rebuilt on screeen size change
    vector<Space>       m_BackScreenSpaces; // will be growing
    
    Space               m_EraseChar = DefaultEraseChar();

    unique_ptr<Snapshot>m_Snapshot;
};

inline const TermScreenBuffer::Space*
begin( const pair<const TermScreenBuffer::Space*, const TermScreenBuffer::Space*> &_p )
{ return _p.first; }

inline TermScreenBuffer::Space*
begin( const pair<TermScreenBuffer::Space*, TermScreenBuffer::Space*> &_p )
{ return _p.first; }

inline const TermScreenBuffer::Space*
end( const pair<const TermScreenBuffer::Space*, const TermScreenBuffer::Space*> &_p )
{ return _p.second; }

inline TermScreenBuffer::Space*
end( const pair<TermScreenBuffer::Space*, TermScreenBuffer::Space*> &_p )
{ return _p.second; }
