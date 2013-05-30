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
    m_File = _file;
    if(m_DecodeBuffer != 0)
        free(m_DecodeBuffer);
    if(m_DecodeBufferIndx != 0)
        free(m_DecodeBufferIndx);
    
    m_DecodeBuffer = (UniChar*) malloc(sizeof(UniChar) * m_File->WindowSize());
    m_DecodeBufferIndx = (uint32_t*) malloc(sizeof(uint32_t) * m_File->WindowSize());
    
    
    [self DecodeRawFileBuffer];
    
//    m_ViewImpl = [BigFileViewText alloc];
    m_ViewImpl = [BigFileViewHex alloc];
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

@end
