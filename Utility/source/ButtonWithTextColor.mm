// Copyright (C) 2016 Michael Kazakov. Subject to GNU General Public License version 3.
#include "../include/Utility/ButtonWithTextColor.h"

@implementation ButtonWithTextColor

@synthesize textColor;

- (void) setTitle:(NSString *)title
{
    [super setTitle:title];
    
    if( NSColor *color = self.textColor ) {
        NSMutableAttributedString *colorTitle = [[NSMutableAttributedString alloc] initWithAttributedString:self.attributedTitle];
        NSRange titleRange = NSMakeRange(0, colorTitle.length);
        [colorTitle addAttribute:NSForegroundColorAttributeName value:color range:titleRange];
        self.attributedTitle = colorTitle;
    }
}


@end
