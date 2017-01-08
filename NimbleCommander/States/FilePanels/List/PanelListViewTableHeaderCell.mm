    #include <NimbleCommander/Core/Theming/Theme.h>
#include "PanelListViewTableHeaderCell.h"

@implementation PanelListViewTableHeaderCell

/*
default attributes:
    NSColor = "NSNamedColorSpace System headerTextColor";
 NSColor = "NSNamedColorSpace System headerTextColor";
    NSFont = "\".AppleSystemUIFont 11.00 pt. P [] (0x600000046ea0) fobj=0x101710160, spc=3.17\"";
    NSOriginalFont = "\".AppleSystemUIFont 11.00 pt. P [] (0x600000046ea0) fobj=0x101710160, spc=3.17\"";
    NSParagraphStyle = "Alignment 0,
                        LineSpacing 0,
                        ParagraphSpacing 0,
                        ParagraphSpacingBefore 0,
                        HeadIndent 0,
                        TailIndent 0,
                        FirstLineHeadIndent 0,
                        LineHeight 0/0,
                        LineHeightMultiple 0,
                        LineBreakMode 4,
                        Tabs (\n    28L,\n    56L,\n    84L,\n    112L,\n    140L,\n    168L,\n    196L,\n    224L,\n    252L,\n    280L,\n    308L,\n    336L\n),
                        DefaultTabInterval 0,
                        Blocks (\n),
                        Lists (\n),
                        BaseWritingDirection -1,
                        HyphenationFactor 0,
                        TighteningForTruncation NO,
                        HeaderLevel 0";
*/

/*- (void) setStringValue:(NSString *)stringValue
{
    [super setStringValue:stringValue];
    
 self.attributedStringValue = [[NSAttributedString alloc] initWithString:self.stringValue
    attributes:@{NSFontAttributeName: CurrentTheme().FilePanelsListHeaderFont(),
    
    NSForegroundColorAttributeName: CurrentTheme().FilePanelsListHeaderTextColor()
    }];

}*/
/*
- (void) setAttributedStringValue:(NSAttributedString *)attributedStringValue
{
    auto as = [[NSMutableAttributedString alloc]
               initWithAttributedString:attributedStringValue
               ];
    [as setAttributes:@{NSFontAttributeName:
                            CurrentTheme().FilePanelsListHeaderFont(),
                        NSForegroundColorAttributeName:
                            CurrentTheme().FilePanelsListHeaderTextColor()}
                range:NSMakeRange(0, as.length)
     ];

    [super setAttributedStringValue:as];
}*/

/*- (NSAttributedString*)attributedStringValue
{
auto as = [[NSMutableAttributedString alloc]
               initWithAttributedString:[super attributedStringValue]
               ];
    [as setAttributes:@{NSFontAttributeName:
                            CurrentTheme().FilePanelsListHeaderFont(),
                        NSForegroundColorAttributeName:
                            CurrentTheme().FilePanelsListHeaderTextColor()}
                range:NSMakeRange(0, as.length)
     ];
return as;

}*/


static void FillRect( NSRect rc, NSColor *c )
{
    [c set];
    if( c.alphaComponent == 1. )
        NSRectFill(rc);
    else
        NSRectFillUsingOperation(rc, NSCompositingOperationSourceAtop);
}

- (void) drawWithFrame:(NSRect)cellFrame inView:(NSView *)controlView
{
//    [super drawWithFrame:cellFrame inView:controlView];
//    return;

    [Theme().FilePanelsListHeaderBackgroundColor() set];
    NSRectFill(cellFrame);

    FillRect(NSMakeRect(cellFrame.origin.x,
                        NSMaxY(cellFrame)-1,
                        cellFrame.size.width,
                        1),
             Theme().FilePanelsListHeaderSeparatorColor()
             );
    if( NSMaxX(cellFrame) < controlView.bounds.size.width )
        FillRect(NSMakeRect(NSMaxX(cellFrame)-1,
                            NSMinY(cellFrame)+3,
                            1,
                            cellFrame.size.height-6),
                 Theme().FilePanelsListHeaderSeparatorColor()
                 );
    
//self.font = CurrentTheme().FilePanelsListHeaderFont();

//    NSParagraphStyle

    auto attrs = @{NSFontAttributeName: CurrentTheme().FilePanelsListHeaderFont(),
                   NSForegroundColorAttributeName: CurrentTheme().FilePanelsListHeaderTextColor(),
                   NSParagraphStyleAttributeName: [&]()->NSParagraphStyle*{
                       NSMutableParagraphStyle *ps = NSParagraphStyle.
                        defaultParagraphStyle.mutableCopy;
                       ps.alignment = self.alignment;
                       return ps;
                   }()
                   };
    self.attributedStringValue = [[NSAttributedString alloc] initWithString:self.stringValue
                                                                 attributes:attrs];
    
    auto trc = [self drawingRectForBounds:cellFrame];
    if( self.alignment & NSTextAlignmentRight )
        trc = NSInsetRect(trc, 4, 4);
    else
        trc = NSInsetRect(trc, 2, 4);
    [self drawInteriorWithFrame:trc inView:controlView];
}

@end
