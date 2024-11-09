// Copyright (C) 2022-2024 Michael Kazakov. Subject to GNU General Public License version 3.
#include "SystemThemeDetector.h"
#include <functional>
#include <Cocoa/Cocoa.h>
#include <Base/dispatch_cpp.h>

// NCSystemThemeDetectorObjCShim listens to both 'AppleInterfaceThemeChangedNotification' notification and to changes of
// 'AppleInterfaceStyle' in the UserDefaults. The reason for that is that these two are inherently racy and there's a
// chance that 'AppleInterfaceStyle' won't be yet updated when queried after receiving
// 'AppleInterfaceThemeChangedNotification'. To work around such case, the code listens to both.
@interface NCSystemThemeDetectorObjCShim : NSObject
@property(readwrite, nonatomic) std::function<void()> onChange;
@end

@implementation NCSystemThemeDetectorObjCShim {
    std::function<void()> m_onChange;
}
@synthesize onChange = m_onChange;

- (instancetype)init
{
    self = [super init];
    if( self ) {
        [NSDistributedNotificationCenter.defaultCenter addObserver:self
                                                          selector:@selector(themeChanged:)
                                                              name:@"AppleInterfaceThemeChangedNotification"
                                                            object:nil];

        [NSUserDefaults.standardUserDefaults addObserver:self forKeyPath:@"AppleInterfaceStyle" options:0 context:nil];
    }
    return self;
}

- (void)dealloc
{
    [NSDistributedNotificationCenter.defaultCenter removeObserver:self
                                                             name:@"AppleInterfaceThemeChangedNotification"
                                                           object:nil];
    [NSUserDefaults.standardUserDefaults removeObserver:self forKeyPath:@"AppleInterfaceStyle" context:nil];
}

- (void)observeValueForKeyPath:(NSString *)keyPath
                      ofObject:(id)object
                        change:(NSDictionary<NSKeyValueChangeKey, id> *)change
                       context:(void *)context
{
    if( m_onChange )
        m_onChange();
}

- (void)themeChanged:(NSNotification *)_notification
{
    if( m_onChange )
        m_onChange();
}

@end

namespace nc {

struct SystemThemeDetector::Impl {
    NCSystemThemeDetectorObjCShim *shim;
    ThemeAppearance appearance = ThemeAppearance::Light;

    static ThemeAppearance Detect();
    void OnChanged();
};

SystemThemeDetector::SystemThemeDetector() : I(std::make_unique<Impl>())
{
    I->appearance = Impl::Detect();
    I->shim = [[NCSystemThemeDetectorObjCShim alloc] init];
    I->shim.onChange = [this] {
        // The 30ms delay is to partially mitigate a race condition between the 'AppleInterfaceThemeChangedNotification'
        // notification and setting the 'AppleInterfaceStyle' value.
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
    NSString *const style = [NSUserDefaults.standardUserDefaults stringForKey:@"AppleInterfaceStyle"];
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
    const auto new_app = Impl::Detect();
    if( new_app == I->appearance )
        return;
    I->appearance = new_app;
    FireObservers(1);
}

SystemThemeDetector::ObservationTicket SystemThemeDetector::ObserveChanges(std::function<void()> _callback)
{
    return AddObserver(std::move(_callback), 1);
}

} // namespace nc
