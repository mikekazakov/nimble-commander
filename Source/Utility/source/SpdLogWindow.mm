// Copyright (C) 2022-2024 Michael Kazakov. Subject to GNU General Public License version 3.
#include "SpdLogWindow.h"
#include <spdlog/spdlog.h>
#include <spdlog/sinks/base_sink.h>
#include <Utility/StringExtras.h>
#include <Utility/ObjCpp.h>
#include <Base/dispatch_cpp.h>
#include <algorithm>
#include <iostream>

namespace nc::utility {

class SpdLogUISink : public spdlog::sinks::base_sink<std::mutex>, public std::enable_shared_from_this<SpdLogUISink>
{
public:
    SpdLogUISink(std::function<void(NSString *)> _feedcb);
    void FlushFromUIThread();

private:
    void sink_it_(const spdlog::details::log_msg &msg) override;
    void flush_() override;
    void Accept(const std::string &_str);
    void DoFlush();

    // A UI callback to hand over the accumulated logs
    std::function<void(NSString *)> m_CB;

    // Logs accumulator, accessible only from the m_Que queue
    std::string m_Stock;

    // The background queue that collects and disposes the logs
    dispatch_queue_t m_Que;
};

SpdLogUISink::SpdLogUISink(std::function<void(NSString *)> _feedcb)
    : m_CB(_feedcb), m_Que(dispatch_queue_create("nc::utility::SpdLogUISink", nullptr))
{
}

void SpdLogUISink::sink_it_(const spdlog::details::log_msg &msg)
{
    spdlog::memory_buf_t formatted;
    spdlog::sinks::base_sink<std::mutex>::formatter_->format(msg, formatted);
    std::string str = fmt::to_string(formatted);
    dispatch_async(m_Que, [wp = std::weak_ptr<SpdLogUISink>(shared_from_this()), str = std::move(str)] {
        if( auto me = wp.lock() ) {
            me->Accept(str);
        }
    });
}

void SpdLogUISink::Accept(const std::string &_str)
{
    dispatch_assert_background_queue();
    m_Stock += _str;
}

void SpdLogUISink::flush_()
{
    // ignore, being drained manually via Flush()
}

void SpdLogUISink::FlushFromUIThread()
{
    dispatch_assert_main_queue();
    dispatch_async(m_Que, [wp = std::weak_ptr<SpdLogUISink>(shared_from_this())] {
        if( auto me = wp.lock() ) {
            me->DoFlush();
        }
    });
}

void SpdLogUISink::DoFlush()
{
    dispatch_assert_background_queue();
    if( m_Stock.empty() )
        return;
    if( auto s = [NSString stringWithUTF8String:m_Stock.c_str()] ) {
        auto callback = m_CB;
        dispatch_to_main_queue([s, callback] { callback(s); });
    }
    else {
        std::cerr << "failed to convert an input string to NSString: " << m_Stock << '\n';
    }
    m_Stock.clear();
}

} // namespace nc::utility

@implementation NCSpdLogWindowController {
    std::span<nc::base::SpdLogger *const> m_Loggers;
    NSScrollView *m_ScrollView;
    NSTextView *m_TextView;
    NSTextStorage *m_TextStorage;
    NSButton *m_NowButton;
    NSButton *m_ClearButton;
    NSButton *m_SettingsButton;
    std::shared_ptr<nc::utility::SpdLogUISink> m_Sink;
    NSTimer *m_DrainTimer;
    NSDictionary<NSAttributedStringKey, id> *m_TextAttrs;
    NSDictionary<NSAttributedStringKey, id> *m_WarningAttrs;
    NSDictionary<NSAttributedStringKey, id> *m_ErrorAttrs;
    NSDictionary<NSAttributedStringKey, id> *m_CriticalAttrs;
    bool m_AutoScroll;
}

- (instancetype)initWithLogs:(std::span<nc::base::SpdLogger *const>)_loggers
{
    auto wnd = [NCSpdLogWindowController makeWindow];
    self = [super initWithWindow:wnd];
    if( self ) {
        wnd.delegate = self;
        m_AutoScroll = true;
        m_Loggers = _loggers;
        [self createControls];

        __weak NCSpdLogWindowController *weak_self = self;
        auto callback = [weak_self](NSString *_str) {
            if( auto me = weak_self )
                [me acceptNewString:_str];
        };
        m_Sink = std::make_shared<nc::utility::SpdLogUISink>(callback);

        for( auto log : _loggers )
            log->Get().sinks().push_back(m_Sink);
    }
    return self;
}

- (void)dealloc
{
}

- (IBAction)showWindow:(id)_sender
{
    m_DrainTimer = [NSTimer scheduledTimerWithTimeInterval:1. / 15.
                                                    target:self
                                                  selector:@selector(drain:)
                                                  userInfo:nil
                                                   repeats:YES];
    m_DrainTimer.tolerance = m_DrainTimer.timeInterval;

    [super showWindow:_sender];
}

- (void)windowWillClose:(NSNotification *)notification
{
    [m_DrainTimer invalidate];
    m_DrainTimer = nil;
}

- (void)createControls
{
    auto wnd = self.window;
    auto cv = wnd.contentView;

    NSTextView *tv = [[NSTextView alloc] initWithFrame:NSMakeRect(0, 0, 0, 0)];
    tv.delegate = self;
    tv.editable = false;
    tv.minSize = NSMakeSize(0, 0);
    tv.maxSize = NSMakeSize(std::numeric_limits<double>::max(), std::numeric_limits<double>::max());
    tv.textContainer.containerSize = NSMakeSize(std::numeric_limits<double>::max(), std::numeric_limits<double>::max());
    tv.textContainer.widthTracksTextView = false;
    tv.autoresizingMask = NSViewWidthSizable | NSViewHeightSizable;
    [tv setHorizontallyResizable:true];
    [tv setVerticallyResizable:true];

    NSScrollView *sv = [[NSScrollView alloc] initWithFrame:NSMakeRect(0, 0, 0, 0)];
    sv.borderType = NSLineBorder;
    sv.translatesAutoresizingMaskIntoConstraints = false;
    sv.hasVerticalScroller = true;
    sv.hasHorizontalScroller = true;
    sv.documentView = tv;
    [cv addSubview:sv];

    NSButton *now = [[NSButton alloc] initWithFrame:NSMakeRect(0, 0, 0, 0)];
    now.translatesAutoresizingMaskIntoConstraints = false;
    now.image = [NSImage imageNamed:NSImageNameFollowLinkFreestandingTemplate];
    now.bordered = false;
    now.bezelStyle = NSBezelStyleShadowlessSquare;
    now.state = NSControlStateValueOn;
    now.allowsMixedState = false;
    [now setButtonType:NSButtonTypeToggle];
    now.target = self;
    now.action = @selector(onNowButtonClicked:);
    now.toolTip = @"Autoscroll to the bottom";
    [cv addSubview:now];

    NSButton *clear = [[NSButton alloc] initWithFrame:NSMakeRect(0, 0, 0, 0)];
    clear.translatesAutoresizingMaskIntoConstraints = false;
    clear.image = [NSImage imageNamed:NSImageNameStopProgressFreestandingTemplate];
    clear.bordered = false;
    clear.bezelStyle = NSBezelStyleShadowlessSquare;
    [clear setButtonType:NSButtonTypeMomentaryPushIn];
    clear.target = self;
    clear.action = @selector(onClearButtonClicked:);
    clear.toolTip = @"Clear the logs";
    [cv addSubview:clear];

    NSButton *settings = [[NSButton alloc] initWithFrame:NSMakeRect(0, 0, 0, 0)];
    settings.translatesAutoresizingMaskIntoConstraints = false;
    settings.image = [NSImage imageNamed:NSImageNameSmartBadgeTemplate];
    settings.bordered = false;
    settings.bezelStyle = NSBezelStyleShadowlessSquare;
    [settings setButtonType:NSButtonTypeMomentaryPushIn];
    settings.target = self;
    settings.action = @selector(onSettingsButtonClicked:);
    settings.toolTip = @"Adjust the logging settings";
    [cv addSubview:settings];

    const auto constraints = std::to_array({@"|-[now(==24)]-[clear(==24)]-[settings(==24)]",
                                            @"|-[sv]-|",
                                            @"V:|-(==4)-[now(==24)]-(==4)-[sv]-|",
                                            @"V:|-(==4)-[clear(==24)]",
                                            @"V:|-(==4)-[settings(==24)]"});
    for( auto constraint : constraints )
        [cv addConstraints:[NSLayoutConstraint
                               constraintsWithVisualFormat:constraint
                                                   options:0
                                                   metrics:nil
                                                     views:NSDictionaryOfVariableBindings(sv, now, clear, settings)]];

    m_TextAttrs = @{
        NSFontAttributeName: [NSFont monospacedSystemFontOfSize:10. weight:NSFontWeightRegular],
        NSForegroundColorAttributeName: NSColor.textColor
    };
    m_WarningAttrs = @{
        NSFontAttributeName: [NSFont monospacedSystemFontOfSize:10. weight:NSFontWeightSemibold],
        NSForegroundColorAttributeName: NSColor.systemYellowColor
    };
    m_ErrorAttrs = @{
        NSFontAttributeName: [NSFont monospacedSystemFontOfSize:10. weight:NSFontWeightSemibold],
        NSForegroundColorAttributeName: NSColor.systemRedColor
    };
    m_CriticalAttrs = @{
        NSFontAttributeName: [NSFont monospacedSystemFontOfSize:10. weight:NSFontWeightBold],
        NSForegroundColorAttributeName: NSColor.systemRedColor
    };

    m_ScrollView = sv;
    m_TextView = tv;
    m_TextStorage = tv.textStorage;
    m_NowButton = now;
    m_ClearButton = clear;
    m_SettingsButton = settings;

    [self.window makeFirstResponder:tv];
}

+ (NSWindow *)makeWindow
{
    auto rc = NSMakeRect(100, 100, 1000, 700);
    auto style = NSWindowStyleMaskTitled | NSWindowStyleMaskClosable | NSWindowStyleMaskMiniaturizable |
                 NSWindowStyleMaskResizable | NSWindowStyleMaskUtilityWindow;
    auto backing = NSBackingStoreBuffered;

    auto wnd = [[NSPanel alloc] initWithContentRect:rc styleMask:style backing:backing defer:true];
    wnd.minSize = {400, 300};
    wnd.title = @"Logs";
    [wnd setFrameAutosaveName:@"NCSpdLogWindow"]; // doesn't work??
    return wnd;
}

- (void)highlightString:(NSMutableAttributedString *)_str
         withAttributes:(NSDictionary<NSAttributedStringKey, id> *)_attrs
           forSubstring:(NSString *)_sub_str
{
    NSString *str = _str.string;
    const size_t length = str.length;

    NSRange search_range = NSMakeRange(0, str.length);
    NSRange found;
    while( (found = [str rangeOfString:_sub_str options:0 range:search_range]).location != NSNotFound ) {
        [_str setAttributes:_attrs range:found];
        search_range = NSMakeRange(NSMaxRange(found), length - NSMaxRange(found));
    }
}

- (void)highlightString:(NSMutableAttributedString *)_str
{
    [self highlightString:_str withAttributes:m_WarningAttrs forSubstring:@" [warning] "];
    [self highlightString:_str withAttributes:m_ErrorAttrs forSubstring:@" [error] "];
    [self highlightString:_str withAttributes:m_CriticalAttrs forSubstring:@" [critical] "];
}

- (void)acceptNewString:(NSString *)_str
{
    dispatch_assert_main_queue();
    assert(_str != nil);
    if( auto as = [[NSMutableAttributedString alloc] initWithString:_str attributes:m_TextAttrs] ) {
        [self highlightString:as];
        [m_TextStorage appendAttributedString:as];
        if( m_AutoScroll )
            [m_TextView scrollToEndOfDocument:nil];
    }
}

- (void)drain:(NSTimer *)_timer
{
    m_Sink->FlushFromUIThread();
}

- (void)onNowButtonClicked:(id)_sender
{
    m_AutoScroll = !m_AutoScroll;
}

- (void)onClearButtonClicked:(id)_sender
{
    [m_TextStorage replaceCharactersInRange:NSMakeRange(0, m_TextStorage.length) withString:@""];
}

static constexpr NSInteger packIntoTag(spdlog::level::level_enum _level, unsigned _idx)
{
    return (static_cast<unsigned>(_level) << 16) | (_idx);
}

static constexpr std::pair<spdlog::level::level_enum, unsigned> unpackFromTag(NSInteger _tag)
{
    return {static_cast<spdlog::level::level_enum>(_tag >> 16), static_cast<unsigned>(_tag & 0xFFFF)};
}

- (void)onSettingsButtonClicked:(id)_sender
{
    using namespace spdlog;

    auto menu = [[NSMenu alloc] init];

    const auto all_are = [&](level::level_enum _level) {
        return std::ranges::all_of(m_Loggers, [_level](auto logger) { return logger->Get().level() == _level; });
    };

    for( unsigned idx = 0; idx <= m_Loggers.size(); ++idx ) {
        nc::base::SpdLogger *const logger = idx < m_Loggers.size() ? m_Loggers[idx] : nullptr;

        auto submenu = [[NSMenu alloc] init];

        NSMenuItem *trace = [submenu addItemWithTitle:@"Trace"
                                               action:@selector(onSettingsLevelClicked:)
                                        keyEquivalent:@""];
        trace.tag = packIntoTag(level::trace, idx);
        if( (logger && logger->Get().level() == level::trace) || (!logger && all_are(level::trace)) )
            trace.state = NSControlStateValueOn;

        NSMenuItem *dbg = [submenu addItemWithTitle:@"Debug"
                                             action:@selector(onSettingsLevelClicked:)
                                      keyEquivalent:@""];
        dbg.tag = packIntoTag(level::debug, idx);
        if( (logger && logger->Get().level() == level::debug) || (!logger && all_are(level::debug)) )
            dbg.state = NSControlStateValueOn;

        NSMenuItem *info = [submenu addItemWithTitle:@"Info"
                                              action:@selector(onSettingsLevelClicked:)
                                       keyEquivalent:@""];
        info.tag = packIntoTag(level::info, idx);
        if( (logger && logger->Get().level() == level::info) || (!logger && all_are(level::info)) )
            info.state = NSControlStateValueOn;

        NSMenuItem *warn = [submenu addItemWithTitle:@"Warning"
                                              action:@selector(onSettingsLevelClicked:)
                                       keyEquivalent:@""];
        warn.tag = packIntoTag(level::warn, idx);
        if( (logger && logger->Get().level() == level::warn) || (!logger && all_are(level::warn)) )
            warn.state = NSControlStateValueOn;

        NSMenuItem *err = [submenu addItemWithTitle:@"Error"
                                             action:@selector(onSettingsLevelClicked:)
                                      keyEquivalent:@""];
        err.tag = packIntoTag(level::err, idx);
        if( (logger && logger->Get().level() == level::err) || (!logger && all_are(level::err)) )
            err.state = NSControlStateValueOn;

        NSMenuItem *cri = [submenu addItemWithTitle:@"Critical"
                                             action:@selector(onSettingsLevelClicked:)
                                      keyEquivalent:@""];
        cri.tag = packIntoTag(level::critical, idx);
        if( (logger && logger->Get().level() == level::critical) || (!logger && all_are(level::critical)) )
            cri.state = NSControlStateValueOn;

        NSMenuItem *off = [submenu addItemWithTitle:@"Off" action:@selector(onSettingsLevelClicked:) keyEquivalent:@""];
        off.tag = packIntoTag(level::off, idx);
        if( (logger && logger->Get().level() == level::off) || (!logger && all_are(level::off)) )
            off.state = NSControlStateValueOn;

        if( logger ) {
            NSMenuItem *menu_holder = [menu addItemWithTitle:[NSString stringWithUTF8StdString:logger->Name()]
                                                      action:nil
                                               keyEquivalent:@""];
            menu_holder.submenu = submenu;
        }
        else {
            [menu addItem:NSMenuItem.separatorItem];
            NSMenuItem *menu_holder = [menu addItemWithTitle:@"all" action:nil keyEquivalent:@""];
            menu_holder.submenu = submenu;
        }
    }

    const auto r = m_SettingsButton.bounds;
    [menu popUpMenuPositioningItem:nil atLocation:NSMakePoint(NSMaxX(r), NSMinY(r)) inView:m_SettingsButton];
}

- (void)onSettingsLevelClicked:(id)_sender
{
    if( auto menu_item = nc::objc_cast<NSMenuItem>(_sender) ) {
        const auto [level, idx] = unpackFromTag(menu_item.tag);
        if( idx < m_Loggers.size() ) {
            m_Loggers[idx]->Get().set_level(level);
        }
        else {
            for( auto logger : m_Loggers )
                logger->Get().set_level(level);
        }
    }
}

@end
