// Copyright (C) 2022 Michael Kazakov. Subject to GNU General Public License version 3.
#include "SystemThemeDetector.h"
#include <functional>
#include <Cocoa/Cocoa.h>
#include <Habanero/dispatch_cpp.h>

@interface NCSystemThemeDetectorObjCShim : NSObject
@property(readwrite, nonatomic) std::function<void()> onChange;
@end

@implementation NCSystemThemeDetectorObjCShim

- (instancetype)init
{
    if( self = [super init] ) {
        [NSDistributedNotificationCenter.defaultCenter addObserver:self
                                                          selector:@selector(themeChanged:)
                                                              name:@"AppleInterfaceThemeChangedNotification"
                                                            object:nil];
    }
    return self;
}

- (void)dealloc
{
    [NSDistributedNotificationCenter.defaultCenter removeObserver:self
                                                             name:@"AppleInterfaceThemeChangedNotification"
                                                           object:nil];
}

- (void)themeChanged:(NSNotification *)_notification
{
    NSLog(@"AppleInterfaceThemeChangedNotification fired, %@", _notification);
    if( _onChange )
        _onChange();
}

@end

namespace nc {

struct SystemThemeDetector::Impl {
    NCSystemThemeDetectorObjCShim *shim;
    ThemeAppearance appearance = ThemeAppearance::Light;

    ThemeAppearance Detect();
    void OnChanged();
};

SystemThemeDetector::SystemThemeDetector() : I(std::make_unique<Impl>())
{
    I->appearance = I->Detect();
    I->shim = [[NCSystemThemeDetectorObjCShim alloc] init];
    I->shim.onChange = [this] {
        // there's an inherit race condition between "AppleInterfaceStyle" in the user defaults and the
        // "AppleInterfaceThemeChangedNotification" notification. Don't know a valid way to work around it, so let's
        // just delay the read from user defaults by some time and pretent there's no race condition.
        // MB observe this value directly via KVO instead?
        dispatch_to_main_queue_after(std::chrono::milliseconds{30}, [this] { OnChanged(); });
    };
}

SystemThemeDetector::~SystemThemeDetector() = default;

// if macOS_10.15
//    if UserDefaults(AppleInterfaceStyleSwitchesAutomatically) == TRUE
//        if UserDefaults(AppleInterfaceStyle) == NIL
//            theme = dark // is nil, means it's dark and will switch in future to light
//        else
//            theme = light //means it's light and will switch in future to dark
//        endif
//    else
//        if UserDefaults(AppleInterfaceStyle) == NIL
//            theme = light
//        else
//            theme = dark
//        endif
//    endif

ThemeAppearance SystemThemeDetector::SystemAppearance() const noexcept
{
    return I->appearance;
}

ThemeAppearance SystemThemeDetector::Impl::Detect()
{
    // TODO: check me on different versions!
    NSString *style = [NSUserDefaults.standardUserDefaults stringForKey:@"AppleInterfaceStyle"];
    //    NSLog(@"%@", style);
    if( style == nil )
        return ThemeAppearance::Light;
    else {
        if( [style.lowercaseString containsString:@"dark"] )
            return ThemeAppearance::Dark;
        else
            return ThemeAppearance::Light;
    }
}

void SystemThemeDetector::OnChanged()
{
    const auto new_app = I->Detect();
    if( new_app == I->appearance )
        return;
    I->appearance = new_app;
    NSLog(@"Changed to %@", I->appearance == ThemeAppearance::Light ? @"light" : @"dark");
    FireObservers(1);
}

SystemThemeDetector::ObservationTicket SystemThemeDetector::ObserveChanges(std::function<void()> _callback)
{
    return AddObserver(std::move(_callback), 1);
}

} // namespace nc
