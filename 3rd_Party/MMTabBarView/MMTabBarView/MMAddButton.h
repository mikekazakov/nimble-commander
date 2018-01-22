#if __has_feature(modules)
@import Cocoa;
#else
#import <Cocoa/Cocoa.h>
#endif

#import "MMRolloverButton.h"

NS_ASSUME_NONNULL_BEGIN

@interface MMAddButton : MMRolloverButton

@property (nullable) SEL longPressAction;

@end

NS_ASSUME_NONNULL_END
