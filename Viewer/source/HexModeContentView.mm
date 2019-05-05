#include "HexModeContentView.h"
#include <cmath>
#include <cassert>
#include <iostream>
@implementation NCViewerHexModeContentView
{
    std::shared_ptr<const nc::viewer::HexModeFrame> m_Frame;
    long m_FileSize;
}

@synthesize hexFrame = m_Frame;
@synthesize fileSize = m_FileSize;

- (instancetype)initWithFrame:(NSRect)_frame
{
    if( self = [super initWithFrame:_frame] ) {
        self.translatesAutoresizingMaskIntoConstraints = false;
        m_FileSize = 0;
        
    }
    return self;
}

- (BOOL)isFlipped
{
    return true;
}

- (void)drawRect:(NSRect)dirtyRect
{
    const auto context = NSGraphicsContext.currentContext.CGContext;
    CGContextSetFillColorWithColor(context, CGColorGetConstantColor(kCGColorBlack));
    CGContextFillRect(context, NSRectToCGRect(dirtyRect));
    
    CGAffineTransform transform;
    transform.a = 1.;
    transform.b = 0.;
    transform.c = 0.;
    transform.d = -1.;
    transform.tx = 0.;
    transform.ty = 0.;
    CGContextSetTextMatrix(context, transform);
    CGContextSetTextDrawingMode(context, kCGTextFill);
    CGContextSetShouldSmoothFonts(context, true);
    CGContextSetShouldAntialias(context, true);
    
    if( m_Frame == nullptr || m_Frame->Empty() )
        return;
    
    assert( m_Frame->BytesPerRow() == 16 );
    
//    CGPoint text_origin = CGPointMake(0., 0.);
    
//    const auto text_origin = CGPointMake
//    ( line_pos.x, line_pos.y + m_FontInfo.LineHeight() - m_FontInfo.Descent() );

//    auto text_origin = CGPointMake
//    ( /*line_pos.x*/0., /*line_pos.y*/0. + m_Frame->FontInfo().LineHeight() - m_Frame->FontInfo().Descent() );
//

//
//    for( int i = 0; i < m_Frame->NumberOfRows(); ++i ) {
//        auto &row = m_Frame->RowAtIndex(i);
//
//
//
//        // draw the text line itself
//        CGContextSetTextPosition( context, text_origin.x, text_origin.y );
//        CTLineDraw(row.AddressLine(), context );
//        text_origin.y += m_Frame->FontInfo().LineHeight();
//    }

    std::cout << "dirty rect origin y: " << dirtyRect.origin.y << std::endl;
    
    const long global_row_index_start =
        (long)std::floor(dirtyRect.origin.y / m_Frame->FontInfo().LineHeight());
    const long global_row_index_end = global_row_index_start +
        (long)std::ceil(dirtyRect.size.height / m_Frame->FontInfo().LineHeight());
    const long global_index_of_first_row =
        (long(m_Frame->RowAtIndex(0).BytesStart()) + m_Frame->WorkingSet().GlobalOffset()) /
        m_Frame->BytesPerRow();
    const long index_start = global_row_index_start - global_index_of_first_row;
    const long index_end = global_row_index_end - global_index_of_first_row;
    CGPoint line_origin = CGPointMake(0., global_row_index_start * m_Frame->FontInfo().LineHeight());
    std::cout << "line origin y: " << line_origin.y << std::endl;
    for( long index = index_start;
        index < index_end;
        ++index, line_origin.y += m_Frame->FontInfo().LineHeight() ) {
        if( index < 0 || index >= m_Frame->NumberOfRows() )
            continue;
        
        const auto text_origin = CGPointMake(line_origin.x,
                                             line_origin.y +
                                             m_Frame->FontInfo().LineHeight() -
                                             m_Frame->FontInfo().Descent() );
        
        auto &row = m_Frame->RowAtIndex(int(index));
        CGContextSetTextPosition( context, text_origin.x, text_origin.y );
        CTLineDraw(row.AddressLine(), context );
        
        CGContextSetTextPosition( context, text_origin.x + 100, text_origin.y );
        CTLineDraw(row.ColumnLine(0), context );
    }
    
//    for( long index =   )

    
    
}

- (NSSize)intrinsicContentSize
{
    if( m_Frame == nullptr ) {
        return NSMakeSize(NSViewNoIntrinsicMetric, NSViewNoIntrinsicMetric);
    }
    else {
        double d = 10000000000.;
        
        return NSMakeSize(NSViewNoIntrinsicMetric, 1e+10);
//        return NSMakeSize(NSViewNoIntrinsicMetric, 1.1e+10);
        
        const auto bytes_per_row = m_Frame->BytesPerRow();
        const auto rows = (m_FileSize / bytes_per_row) +
                          (m_FileSize % bytes_per_row != 0 ? 1 : 0);
        const auto sz = NSMakeSize(NSViewNoIntrinsicMetric,
                                   m_Frame->FontInfo().LineHeight() * rows);
        std::cout << "intrinsic height:" << sz.height << std::endl;
        return sz;
    }
}

- (void)setHexFrame:(std::shared_ptr<const nc::viewer::HexModeFrame>)_hex_frame
{
    if( m_Frame == _hex_frame )
        return;
    m_Frame = _hex_frame;
    [self invalidateIntrinsicContentSize];
    [self setNeedsDisplay:true];
}

- (void)setFileSize:(long)_file_size
{
    if( m_FileSize == _file_size )
        return;
    
    m_FileSize = _file_size;
    [self invalidateIntrinsicContentSize];
}

@end
