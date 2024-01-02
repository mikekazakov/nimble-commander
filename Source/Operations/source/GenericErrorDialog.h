// Copyright (C) 2017-2018 Michael Kazakov. Subject to GNU General Public License version 3.
#pragma once
#import <Cocoa/Cocoa.h>

#include "AsyncDialogResponse.h"

namespace nc::ops{

enum class GenericErrorDialogStyle
{
    Stop    = 0,
    Caution = 1
};

}

@interface NCOpsGenericErrorDialog : NSWindowController

- (instancetype)init;
- (instancetype)initWithContext:(std::shared_ptr<nc::ops::AsyncDialogResponse>)_context;

@property (nonatomic) nc::ops::GenericErrorDialogStyle style;
@property (nonatomic) NSModalResponse escapeButtonResponse;
@property (nonatomic) NSString* message;
@property (nonatomic) NSString* path;
@property (nonatomic) NSString* error;
@property (nonatomic) int errorNo;
@property (nonatomic) bool showApplyToAll;

- (void) addButtonWithTitle:(NSString*)_title responseCode:(NSModalResponse)_response;
- (void) addAbortButton;
- (void) addSkipButton;
- (void) addSkipAllButton;

@end
