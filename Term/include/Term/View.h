// Copyright (C) 2013-2018 Michael Kazakov. Subject to GNU General Public License version 3.
#pragma once

#include <Utility/FPSLimitedDrawer.h>
#include <Utility/FontCache.h>

#include "Screen.h"
#include "Parser.h"
#include "CursorMode.h"

namespace nc::term {
    class Settings;
}

@interface NCTermView : NSView<ViewWithFPSLimitedDrawer>

@property (nonatomic, readonly) FPSLimitedDrawer *fpsDrawer;
@property (nonatomic, readonly) const nc::utility::FontCache &fontCache;
@property (nonatomic, readonly) nc::term::Parser *parser; // may be nullptr
@property (nonatomic) bool reportsSizeByOccupiedContent;
@property (nonatomic) bool allowCursorBlinking;
@property (nonatomic) NSFont  *font;
@property (nonatomic) NSColor *foregroundColor;
@property (nonatomic) NSColor *boldForegroundColor;
@property (nonatomic) NSColor *backgroundColor;
@property (nonatomic) NSColor *selectionColor;
@property (nonatomic) NSColor *cursorColor;
@property (nonatomic) NSColor *ansiColor0;
@property (nonatomic) NSColor *ansiColor1;
@property (nonatomic) NSColor *ansiColor2;
@property (nonatomic) NSColor *ansiColor3;
@property (nonatomic) NSColor *ansiColor4;
@property (nonatomic) NSColor *ansiColor5;
@property (nonatomic) NSColor *ansiColor6;
@property (nonatomic) NSColor *ansiColor7;
@property (nonatomic) NSColor *ansiColor8;
@property (nonatomic) NSColor *ansiColor9;
@property (nonatomic) NSColor *ansiColorA;
@property (nonatomic) NSColor *ansiColorB;
@property (nonatomic) NSColor *ansiColorC;
@property (nonatomic) NSColor *ansiColorD;
@property (nonatomic) NSColor *ansiColorE;
@property (nonatomic) NSColor *ansiColorF;
@property (nonatomic) nc::term::CursorMode cursorMode;

@property (nonatomic) std::shared_ptr<nc::term::Settings> settings;

- (void) AttachToScreen:(nc::term::Screen*)_scr;
- (void) AttachToParser:(nc::term::Parser*)_par;

- (void) adjustSizes:(bool)_mandatory; // implicitly calls scrollToBottom when full height changes
- (void) scrollToBottom;

- (NSPoint)beginningOfScreenLine:(int)_line_number;

@end
