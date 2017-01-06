    #include <NimbleCommander/Core/Theming/Theme.h>
#include "PanelListViewTableHeaderCell.h"

@implementation PanelListViewTableHeaderCell

- (id) init
{
    self = [super init];
    if(self){
    }
    return self;
}

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
- (void) setStringValue:(NSString *)stringValue
{
    [super setStringValue:stringValue];
    
 self.attributedStringValue = [[NSAttributedString alloc] initWithString:self.stringValue
    attributes:@{NSFontAttributeName: CurrentTheme().FilePanelsListHeaderFont(),
    
    NSForegroundColorAttributeName: CurrentTheme().FilePanelsListHeaderTextColor()
    }];

}

- (void) drawWithFrame:(NSRect)cellFrame inView:(NSView *)controlView
{
    //self.backgroundColor = CurrentTheme().FilePanelsListHeaderBackgroundColor();
    
/*attributedStringValue = NSAttributedString(string: stringValue, attributes: [
            NSFontAttributeName: NSFont.systemFont(ofSize: 11, weight: NSFontWeightSemibold),
            NSForegroundColorAttributeName: NSColor(white: 0.4, alpha: 1),
        ])*/
//    auto v = self.attributedStringValue;
//    NSLog(@"%@", self.stringValue);

   //    auto v = self.attributedStringValue;
   
//   self.backgroundColor = NSColor.yellowColor;
    
    
    
    [super drawWithFrame:cellFrame inView:controlView];
    
    
    
    
/*
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
}
*/


//    [self drawInteriorWithFrame:cellFrame inView:controlView];
}

/*
- (void)highlight:(BOOL)flag withFrame:(NSRect)cellFrame inView:(NSView *)controlView
{

int a = 10;
}
*/
/*
- (void) drawInteriorWithFrame:(NSRect)cellFrame inView:(NSView *)controlView
{
    const auto rc = [self titleRectForBounds:cellFrame];
    [self.attributedStringValue drawInRect:rc];
}*/

/*
    override func drawWithFrame(cellFrame: NSRect, inView controlView: NSView)
    {
        super.drawWithFrame(cellFrame, inView: controlView) // since that is what draws borders
        NSColor().symplyBackgroundGrayColor().setFill()
        NSRectFill(cellFrame)
        self.drawInteriorWithFrame(cellFrame, inView: controlView)
    }

    override func drawInteriorWithFrame(cellFrame: NSRect, inView controlView: NSView)
    {
        let titleRect = self.titleRectForBounds(cellFrame)
        self.attributedStringValue.drawInRect(titleRect)
    }
*/
/*- (void) setBackgroundColor:(NSColor *)backgroundColor
{
    [super setBackgroundColor:backgroundColor];
}*/

@end
