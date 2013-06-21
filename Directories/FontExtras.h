//
//  FontExtras.h
//  Files
//
//  Created by Michael G. Kazakov on 21.06.13.
//  Copyright (c) 2013 Michael G. Kazakov. All rights reserved.
//

#pragma once

double GetLineHeightForFont(CTFontRef iFont, CGFloat *_ascent=0, CGFloat *_descent=0, CGFloat *_leading=0);
double GetMonospaceFontCharWidth(CTFontRef _font);