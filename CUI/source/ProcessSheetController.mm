// Copyright (C) 2014-2020 Michael Kazakov. Subject to GNU General Public License version 3.
#include "ProcessSheetController.h"
#include <Utility/CocoaAppearanceManager.h>
#include <Habanero/dispatch_cpp.h>
#include <Habanero/CommonPaths.h>
#include <filesystem>
#include <cassert>

static const std::chrono::nanoseconds g_ShowDelay = std::chrono::milliseconds{150};

static NSBundle *Bundle() noexcept
{
    static NSBundle *const bundle = []() -> NSBundle * {
        const std::filesystem::path packaged = "Contents/Resources/CUIResources.bundle";
        const std::filesystem::path non_packaged = "CUIResources.bundle";
        const std::filesystem::path base = nc::base::CommonPaths::AppBundle();

        if( auto path = base / packaged; std::filesystem::is_directory(path) ) {
            // packaged structure
            NSString *const ns_path = [NSString stringWithUTF8String:path.c_str()];
            return [NSBundle bundleWithPath:ns_path];
        }
        if( auto path = base / non_packaged; std::filesystem::is_directory(path) ) {
            // non-packaged structure
            NSString *const ns_path = [NSString stringWithUTF8String:path.c_str()];
            return [NSBundle bundleWithPath:ns_path];
        }
        return nil;
    }();
    assert(bundle != nil);
    return bundle;
}

@interface ProcessSheetController()
@property (nonatomic) IBOutlet NSTextField *titleTextField;
@property (nonatomic) IBOutlet NSProgressIndicator *progressIndicator;
@end

@implementation ProcessSheetController
{
    bool m_Running;
    bool m_UserCancelled;
    bool m_ClientClosed;
    double m_Progress;
}

@synthesize userCancelled = m_UserCancelled;

- (id)init
{
    // NEED EVEN MOAR GCD HACKS!!
    if(dispatch_is_main_queue()) {
        const auto nib_path = [Bundle() pathForResource:@"ProcessSheetController" ofType:@"nib"];
        self = [super initWithWindowNibPath:nib_path owner:self];
        (void)self.window;
    }
    else {
        __block ProcessSheetController *me = self;
        dispatch_sync(dispatch_get_main_queue(), ^{
            const auto nib_path = [Bundle() pathForResource:@"ProcessSheetController" ofType:@"nib"];
            me = [super initWithWindowNibPath:nib_path owner:me];
            (void)me.window;
        });
        self = me;
    }
    if(self) {
        m_Progress = 0.;
        self.window.movableByWindowBackground = true;
        m_Running = false;
        m_UserCancelled = false;
        m_ClientClosed = false;
    }
    return self;    
}

- (void) windowDidLoad
{
    [super windowDidLoad];
    nc::utility::CocoaAppearanceManager::Instance().ManageWindowApperance(self.window);
}


- (IBAction)OnCancel:(id)[[maybe_unused]]_sender
{
    m_UserCancelled = true;
    if(self.OnCancelOperation)
        self.OnCancelOperation();

    [self Discard];
}

- (void)Show
{
    // consider using modal dialog here.
    
    if(m_Running == true)
        return;
    dispatch_to_main_queue_after(g_ShowDelay,[=]{
        if(m_ClientClosed)
            return;
        [self showWindow:self];
        m_Running = true;
    });
}

- (void)Close
{
    m_ClientClosed = true;
    [self Discard];
}

- (void) Discard
{
    if(m_Running == false)
        return;
    
    dispatch_to_main_queue([=]{ [self.window close]; });
    m_Running = false;
}

- (void) setTitle:(NSString *)title
{
    if( dispatch_is_main_queue() ) {
        self.titleTextField.stringValue = title;
    }
    else {
        dispatch_async(dispatch_get_main_queue(), [=]{
            self.titleTextField.stringValue = title;    
        });
    }
}

- (NSString*) title
{
    if( dispatch_is_main_queue() ) {
        return self.titleTextField.stringValue;
    }
    else {
        NSString *result = nil;
        dispatch_sync(dispatch_get_main_queue(), [=, &result]{
            result = self.titleTextField.stringValue; 
        });        
        return result;
    }
}

- (void)setProgress:(double)progress
{
    if( progress == m_Progress )
        return;
    m_Progress = progress; 
    if( dispatch_is_main_queue() ) {
        self.progressIndicator.doubleValue = m_Progress; 
    }
    else {
        dispatch_async(dispatch_get_main_queue(), [=]{
            self.progressIndicator.doubleValue = m_Progress;    
        });
    }
}

- (double)progress
{
    return m_Progress;
}

@end
