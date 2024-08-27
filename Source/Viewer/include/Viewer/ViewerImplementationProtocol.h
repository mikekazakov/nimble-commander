// Copyright (C) 2013-2024 Michael Kazakov. Subject to GNU General Public License version 3.
#pragma once

#include <Cocoa/Cocoa.h>
#include <memory>
#include <filesystem>

namespace nc::viewer {
class DataBackend;
};

@protocol NCViewerImplementationProtocol <NSObject>
@optional

// Queries

/**
 * Returns true if the beginning of the file is currently visible in a view.
 */
- (bool)isAtTheBeginning;

/**
 * Returns true if the end of the file is currently visible in a view.
 */
- (bool)isAtTheEnd;

// Requests

/**
 * Inform an implementation that a backend was changed. The viewer implementation must drop any
 * references to a previous backend and switch to the new one.
 */
- (void)attachToNewBackend:(std::shared_ptr<const nc::viewer::DataBackend>)_backend;

/**
 * If a view doesn't use a backend and doesn't provide 'attachToNewBackend' it should provide attachToNewFilepath.
 * That's for a Preview mode.
 */
- (void)attachToNewFilepath:(std::filesystem::path)_path;

/**
 * Non-binding request to show content located at the '_offset' position within the file.
 */
- (bool)scrollToGlobalBytesOffset:(int64_t)_offset;

// Notifications

/**
 * Informs that the backend content was changed, presumably by its momement.
 */
- (void)backendContentHasChanged;

/**
 * Informs that the selection was changed.
 */
- (void)selectionHasChanged;

/**
 * Informs that the line wrapping setting has changed.
 */
- (void)lineWrappingHasChanged;

/**
 * Informs that visual theme provided for the implementation has changed.
 */
- (void)themeHasChanged;

/**
 * Informs that the setting that enables the syntax highlighting has changed.
 */
- (void)syntaxHighlightingEnabled:(bool)_enabled;

/**
 * Updates the current language syntax used for highlighting.
 */
- (void)setHighlightingLanguage:(const std::string &)_language;

@end
