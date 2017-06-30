#pragma once
#import <Cocoa/Cocoa.h>

namespace nc::ops{

enum class GenericErrorDialogStyle
{
    Stop    = 0,
    Caution = 1
};

inline constexpr long NSModalResponseSkip       = -10'000;
inline constexpr long NSModalResponseSkipAll    = -10'001;

}

@interface NCOpsGenericErrorDialog : NSWindowController

- (instancetype)init;

@property (nonatomic) nc::ops::GenericErrorDialogStyle style;
@property (nonatomic) NSModalResponse escapeButtonResponse;
@property (nonatomic) NSString* message;
@property (nonatomic) NSString* path;
@property (nonatomic) NSString* error;
@property (nonatomic) int errorNo;

- (void) addButtonWithTitle:(NSString*)_title responseCode:(NSModalResponse)_response;

@end
