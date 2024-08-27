// Copyright (C) 2013-2024 Michael Kazakov. Subject to GNU General Public License version 3.
#pragma once

#include <Utility/Encodings.h>
#include <VFS/FileWindow.h>
#include "Modes.h"
#include "TextModeViewDelegate.h"
#include "HexModeViewDelegate.h"
#include <memory>
#include <optional>
#include <string>

@class NCViewerFooter;
@class NCViewerSearchView;

namespace nc::utility {
class TemporaryFileStorage;
}
namespace nc::config {
class Config;
}
namespace nc::viewer {
class Theme;
}

namespace nc::viewer::hl {
class SettingsStorage;
}

@interface NCViewerView : NSView <NCViewerTextModeViewDelegate, NCViewerHexModeViewDelegate>

- (instancetype)init NS_UNAVAILABLE;
- (instancetype)initWithFrame:(NSRect)frame NS_UNAVAILABLE;
- (instancetype)initWithFrame:(NSRect)frame
                  tempStorage:(nc::utility::TemporaryFileStorage &)_temp_storage
                       config:(nc::config::Config &)_config
                        theme:(std::unique_ptr<nc::viewer::Theme>)_theme
         highlightingSettings:(nc::viewer::hl::SettingsStorage &)_hl_settings;

- (void)setFile:(std::shared_ptr<nc::vfs::FileWindow>)_file;
- (void)setKnownFile:(std::shared_ptr<nc::vfs::FileWindow>)_file
            encoding:(nc::utility::Encoding)_encoding
                mode:(nc::viewer::ViewMode)_mode
            language:(const std::optional<std::string> &)_language;

// informs NCViewerView that a file window was changed completely, presumably reloaded afresh.
// the view should try to preserve its current visual state while rebuilding its backend structures.
- (void)replaceFile:(std::shared_ptr<nc::vfs::FileWindow>)_file;

/**
 * This will reset the current viewer state.
 */
- (void)detachFromFile;

// Frontend section

/**
 * Setting how data backend should translate raw bytes into UniChars characters.
 * KVO-compatible.
 */
@property(nonatomic) nc::utility::Encoding encoding;

/**
 * Set if text presentation should fit lines into a view width to disable horiziontal scrolling.
 * That is done by breaking sentences by words wrapping.
 * KVO-compatible.
 */
@property(nonatomic) bool wordWrap;

/**
 * Visual presentation mode. Currently supports three: Text, Hex and Preview.
 * KVO-compatible.
 */
@property(nonatomic) nc::viewer::ViewMode mode;

/**
 * Scroll position within whole file, now in a window
 * KVO-compatible.
 */
@property(nonatomic) uint64_t verticalPositionInBytes;

/**
 * Tried to verticalPositionInBytes.
 * KVO-compatible, read-only.
 */
@property(nonatomic, readonly) double verticalPositionPercentage;

/**
 * Selection in whole file, in raw bytes.
 * It may render to different variant within concrete file window position.
 * If set with improper range (larger than whole file), it will be implicitly trimmed
 */
@property(nonatomic) CFRange selectionInFile;

// Language for syntax highlighting in the text mode.
@property(nonatomic) std::string language;

- (void)scrollToVerticalPosition:(double)_p; // [0..1]
- (void)scrollToSelection;
- (CFRange)SelectionWithinWindow;         // bytes within a decoded window
- (CFRange)SelectionWithinWindowUnichars; // unichars within a decoded window

/** Returns an object to be set as a first responder if the Viewer should have a focus. */
@property(nonatomic, readonly) NSResponder *keyboardResponder;

/** If set, NCViewerView will try to redirect performKeyEquivalent: to this responder. */
@property(nonatomic, weak) NSResponder *hotkeyDelegate;

@property(nonatomic, readonly) NCViewerFooter *footer;

@property(nonatomic, readonly) NCViewerSearchView *searchView;

@end
