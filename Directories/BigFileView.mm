//
//  TextView.m
//  ViewerBase
//
//  Created by Michael G. Kazakov on 05.05.13.
//  Copyright (c) 2013 Michael G. Kazakov. All rights reserved.
//

#import "BigFileView.h"
#import "BigFileViewText.h"
#import "BigFileViewHex.h"
#import "BigFileViewEncodingSelection.h"
#import "DataBlockAnalysis.h"
#import "Common.h"

@implementation BigFileView
{
    FileWindow     *m_File;
    
    int             m_Encoding;
    
    // a file's window decoded into Unicode
    UniChar         *m_DecodeBuffer;
    // array indexing every m_DecodeBuffer unicode character into a byte offset within original file window
    uint32_t        *m_DecodeBufferIndx;
    size_t          m_DecodedBufferSize; // amount of unichars

    CTFontRef       m_Font;
    CGColorRef      m_ForegroundColor;
        
    // layout
    bool                         m_DoWrapLines;
    
    __strong id<BigFileViewProtocol>      m_ViewImpl;
    
    NSScroller      *m_VerticalScroller;
}

- (void)awakeFromNib
{
    [self DoInit];
}

- (id)initWithFrame:(NSRect)frame
{
    self = [super initWithFrame:frame];
    if (self) {
        [self DoInit];        
        // Initialization code here.
    }
    
    return self;
}

- (void) dealloc
{
    if(m_File)
    {
        if(m_File->FileOpened())
            m_File->CloseFile();
        delete m_File;
    }

    [[NSNotificationCenter defaultCenter] removeObserver:self];
    CFRelease(m_ForegroundColor);
    CFRelease(m_Font);
}

- (void) DoInit
{
    m_Encoding = ENCODING_UTF8;
    m_DoWrapLines = true;
    m_Font = CTFontCreateWithName(CFSTR("Menlo"), 12, NULL);
    
    CGColorSpaceRef rgbColorSpace = CGColorSpaceCreateDeviceRGB();
    CGFloat components[] = { 0.0, 0.0, 0.0, 1.0 };
    m_ForegroundColor = CGColorCreate(rgbColorSpace, components);
    CGColorSpaceRelease(rgbColorSpace);
    
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(frameDidChange)
                                                 name:NSViewFrameDidChangeNotification
                                               object:self];
    
    NSRect rect = [self frame];
    rect.origin.x = rect.size.width - [NSScroller scrollerWidth];
    rect.size.width = [NSScroller scrollerWidth];
    m_VerticalScroller = [[NSScroller alloc] initWithFrame:rect];
    [m_VerticalScroller setEnabled:YES];
    [m_VerticalScroller setTarget:self];
    [m_VerticalScroller setAction:@selector(VerticalScroll:)];
    [self addSubview:m_VerticalScroller];

    
    
    
    [self frameDidChange];
}

- (BOOL)acceptsFirstResponder
{
    return YES;
}

- (BOOL)isOpaque
{
    return YES;
}

- (void)drawRect:(NSRect)dirtyRect
{
    // Drawing code here.
    CGContextRef context = (CGContextRef)[[NSGraphicsContext currentContext]
                                          graphicsPort];

    if(m_ViewImpl != nil)
        [m_ViewImpl DoDraw:context dirty:dirtyRect];

}

- (void) SetFile:(FileWindow*) _file
{
    StaticDataBlockAnalysis stat;
    DoStaticDataBlockAnalysis(_file->Window(), _file->WindowSize(), &stat);
    
    m_File = _file;
    if(m_DecodeBuffer != 0)
        free(m_DecodeBuffer);
    if(m_DecodeBufferIndx != 0)
        free(m_DecodeBufferIndx);
    
    m_DecodeBuffer = (UniChar*) malloc(sizeof(UniChar) * m_File->WindowSize());
    m_DecodeBufferIndx = (uint32_t*) malloc(sizeof(uint32_t) * m_File->WindowSize());
    
    if(stat.can_be_utf8) m_Encoding = ENCODING_UTF8;
    else                 m_Encoding = ENCODING_MACOS_ROMAN_WESTERN;
    
    [self DecodeRawFileBuffer];    
    
    if(stat.is_binary)  m_ViewImpl = [BigFileViewHex alloc];
    else                m_ViewImpl = [BigFileViewText alloc];
    
    [m_ViewImpl InitWithWindow:m_DecodeBuffer
                       offsets:m_DecodeBufferIndx
                          size:m_DecodedBufferSize
                        parent:self];
}

- (void) DecodeRawFileBuffer
{
    if(m_Encoding == ENCODING_UTF8)
    {
        size_t size;
        InterpretUTF8BufferAsIndexedUniChar(
                                                     (unsigned char*) m_File->Window(),
                                                     m_File->WindowSize(),
                                                     m_DecodeBuffer, // should be at least _input_size 16b words long,
                                                     m_DecodeBufferIndx,
                                                     &size,
                                                     0xFFFD // something like '?' or U+FFFD
                                                    );
        m_DecodedBufferSize = size;
    }
    else if(m_Encoding >= ENCODING_SINGLE_BYTES_FIRST__ && m_Encoding <= ENCODING_SINGLE_BYTES_LAST__)
    {
        InterpretSingleByteBufferAsUniCharPreservingBufferSize((unsigned char*) m_File->Window(),
                                                               m_File->WindowSize(),
                                                               m_DecodeBuffer,
                                                               m_Encoding);
        m_DecodedBufferSize = m_File->WindowSize();
        for(int i = 0; i < m_File->WindowSize(); ++i)
            m_DecodeBufferIndx[i] = i;
    }
    else
        assert(0);
    
    if(m_ViewImpl)
        [m_ViewImpl OnBufferDecoded:m_DecodedBufferSize];
}

- (void)keyDown:(NSEvent *)event
{
    NSString*  const character = [event charactersIgnoringModifiers];
    if ( [character length] != 1 ) return;
    unichar const unicode        = [character characterAtIndex:0];
    unsigned short const keycode = [event keyCode];
//    NSUInteger const modif       = [event modifierFlags];
#define ISMODIFIER(_v) ( (modif&NSDeviceIndependentModifierFlagsMask) == (_v) )
    switch (unicode)
    {
    
    case NSUpArrowFunctionKey:
            [m_ViewImpl OnUpArrow];
            break;
            
    case NSDownArrowFunctionKey:
            [m_ViewImpl OnDownArrow];
            break;
            
    case NSPageDownFunctionKey:
            [m_ViewImpl OnPageDown];
            break;

    case NSPageUpFunctionKey:
            [m_ViewImpl OnPageUp];
            break;
        
    case NSF4FunctionKey:
            [self NextViewType];
            break;
    case NSF8FunctionKey:
            [self SetEncoding];
            break;
            
    }
    
    switch (keycode)
    {
        case 53: // Esc button
            [self DoClose];
            break;
    }
    
    
//    m_VerticalOffset
    
#undef ISMODIFIER
}

- (void) SetEncoding
{
    BigFileViewEncodingSelection *wnd = [BigFileViewEncodingSelection new];
    [wnd SetCurrentEncoding:m_Encoding];
    int ret = (int)[NSApp runModalForWindow: [wnd window]];
    [NSApp endSheet: [wnd window]];
    [[wnd window] orderOut: self];
    
    if(ret != ENCODING_INVALID)
    {
        if(ret != m_Encoding)
        {
            m_Encoding = ret;
            [self DecodeRawFileBuffer];
        }
    }
}

- (void)frameDidChange
{
//    NSRect fr = [self frame];
//    m_FrameLines = fr.size.height / GetLineHeightForFont(m_Font);
}

- (CTFontRef) TextFont
{
    return m_Font;
}

- (CGColorRef) TextForegroundColor
{
    return m_ForegroundColor;
}

- (const void*) RawWindow
{
    return m_File->Window();
}

- (uint64_t) RawWindowPosition
{
    return m_File->WindowPos();
}

- (uint64_t) RawWindowSize
{
    return m_File->WindowSize();
}

- (uint64_t) FullSize
{
    return m_File->FileSize();
}

- (void) RequestWindowMovementAt: (uint64_t) _pos
{
    m_File->MoveWindow(_pos);
    
    [self DecodeRawFileBuffer];
}

- (IBAction)ToggleTextView:(id)sender
{
    m_ViewImpl = [BigFileViewText alloc];
    [m_ViewImpl InitWithWindow:m_DecodeBuffer
                       offsets:m_DecodeBufferIndx
                          size:m_DecodedBufferSize
                        parent:self];
}

- (IBAction)ToggleHexView:(id)sender
{
    m_ViewImpl = [BigFileViewHex alloc];
    [m_ViewImpl InitWithWindow:m_DecodeBuffer
                       offsets:m_DecodeBufferIndx
                          size:m_DecodedBufferSize
                        parent:self];
}

- (void) NextViewType
{
    uint32_t off = [m_ViewImpl GetOffsetWithinWindow];
    
    if( [m_ViewImpl isKindOfClass: [BigFileViewText class]])
        [self ToggleHexView:nil];
    else
        [self ToggleTextView:nil];
    
    [m_ViewImpl MoveOffsetWithinWindow:off];
}

- (void) DoClose
{
    if([self window])
        [[self window] makeFirstResponder:[[self window] windowController]];
    
    [self removeFromSuperview];

    m_ViewImpl = nil;
}

- (void) UpdateVerticalScroll: (double) _pos prop:(double)prop
{
    [m_VerticalScroller setKnobProportion:prop];
    [m_VerticalScroller setDoubleValue:_pos];
}

- (void)VerticalScroll:(id)sender
{

    switch ([m_VerticalScroller hitPart])
    {
        case NSScrollerIncrementLine:
            [m_ViewImpl OnDownArrow];
            break;
        case NSScrollerIncrementPage:
            // Include code here for the case where CTRL + down arrow is pressed, or the space the scroll knob moves in is pressed
            [m_ViewImpl OnPageDown];
            break;
        case NSScrollerDecrementLine:
            // Include code here for the case where the up arrow is pressed
            [m_ViewImpl OnUpArrow];            
            break;
        case NSScrollerDecrementPage:
            // Include code here for the case where CTRL + up arrow is pressed, or the space the scroll knob moves in is pressed
            [m_ViewImpl OnPageUp];
            break;
        case NSScrollerKnob:
            // This case is when the knob itself is pressed
                [m_ViewImpl HandleVerticalScroll:[m_VerticalScroller doubleValue]];
            break;
        default:
            break;
    }
}

- (void)scrollWheel:(NSEvent *)theEvent
{
    int idy = int([theEvent deltaY]); // TODO: temporary implementation
    if(idy < 0)
        [m_ViewImpl OnDownArrow];
    else if(idy > 0)
        [m_ViewImpl OnUpArrow];
}

@end
