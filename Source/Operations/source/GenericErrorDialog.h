// Copyright (C) 2017-2026 Michael Kazakov. Subject to GNU General Public License version 3.
#pragma once
#import <Cocoa/Cocoa.h>
#import <Base/Error.h>

#include "AsyncDialogResponse.h"

namespace nc::ops {

enum class GenericErrorDialogStyle : uint8_t {
    Stop = 0,
    Caution = 1
};

} // namespace nc::ops

@interface NCOpsGenericErrorDialog : NSWindowController

- (instancetype)init;
- (instancetype)initWithContext:(std::shared_ptr<nc::ops::AsyncDialogResponse>)_context;

@property(nonatomic) nc::ops::GenericErrorDialogStyle style;
@property(nonatomic) NSModalResponse escapeButtonResponse;
@property(nonatomic) NSString *message;
@property(nonatomic) NSString *path;
@property(nonatomic) NSString *errorMessage;
@property(nonatomic) bool showApplyToAll;

- (void)setError:(nc::Error)_error;

- (void)addButtonWithTitle:(NSString *)_title responseCode:(NSModalResponse)_response;
- (void)addAbortButton;
- (void)addSkipButton;
- (void)addSkipAllButton;

@end
