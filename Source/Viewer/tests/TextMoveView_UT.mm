// Copyright (C) 2021-2025 Michael Kazakov. Subject to GNU General Public License version 3.
#include "Tests.h"
#include "TextModeView.h"
#include "TextModeFrame.h"
#include "Theme.h"
#include "Highlighting/SettingsStorage.h"
#include "TextModeWorkingSet.h"
#include <Utility/Encodings.h>
#include <Base/algo.h>
#include <VFS/VFSGenericMemReadOnlyFile.h>
#include <VFS/Host.h>
#include <VFS/FileWindow.h>

#include <vector>
#include <numeric>
#include <iostream>

#define PREFIX "NCViewerTextModeView "

using namespace nc::viewer;
using Catch::Approx;

namespace {

struct DummyTheme : Theme {
    [[nodiscard]] NSFont *Font() const override;
    [[nodiscard]] NSColor *OverlayColor() const override;
    [[nodiscard]] NSColor *TextColor() const override;
    [[nodiscard]] NSColor *TextSyntaxCommentColor() const override;
    [[nodiscard]] NSColor *TextSyntaxPreprocessorColor() const override;
    [[nodiscard]] NSColor *TextSyntaxKeywordColor() const override;
    [[nodiscard]] NSColor *TextSyntaxOperatorColor() const override;
    [[nodiscard]] NSColor *TextSyntaxIdentifierColor() const override;
    [[nodiscard]] NSColor *TextSyntaxNumberColor() const override;
    [[nodiscard]] NSColor *TextSyntaxStringColor() const override;
    [[nodiscard]] NSColor *ViewerSelectionColor() const override;
    [[nodiscard]] NSColor *ViewerBackgroundColor() const override;
    void ObserveChanges(std::function<void()> /*_callback*/) override;
};

struct Context {
    Context(std::string_view _string);
    void Reload(std::string_view _new_string);

    std::shared_ptr<nc::vfs::GenericMemReadOnlyFile> file;
    std::shared_ptr<nc::vfs::FileWindow> window;
    std::shared_ptr<DataBackend> backend;
    hl::DummySettingsStorage hl_settings;

private:
    void Open(std::string_view _string);
};

} // namespace

@interface NCViewerTextModeViewMockDelegate : NSObject <NCViewerTextModeViewDelegate>
@property(nonatomic, readwrite) std::function<std::expected<void, nc::Error>(NCViewerTextModeView *, int64_t _position)>
    syncBackendWindowMovement;
@end

static const auto g_MenloRegular13 = [NSFont fontWithName:@"Menlo-Regular" size:13.];
static const auto g_500x100 = NSMakeRect(0., 0., 500., 100.);
[[clang::no_destroy]] static DummyTheme g_DummyTheme;

TEST_CASE(PREFIX "Basic geomtery initialization")
{
    const std::string data = "Hello, world!";
    Context ctx{data}; // NOLINT
    auto view = [[NCViewerTextModeView alloc] initWithFrame:g_500x100
                                                    backend:ctx.backend
                                                      theme:g_DummyTheme
                                       highlightingSettings:ctx.hl_settings
                                         enableHighlighting:false];
    // let's pretend that I happen to know the internal insets and sizes.
    CHECK(view.contentsSize.width == Approx(477.)); // 500-4-4-15
    CHECK(view.contentsSize.height == Approx(100.));
    CHECK(view.numberOfLinesFittingInView == 6); // floor(100 / 15);
    auto &frame = view.textFrame;
    CHECK(frame.LinesNumber() == 1);
    CHECK(frame.Bounds().height == Approx(15.));
    CHECK(frame.Bounds().width == Approx(101).margin(1.));
    CHECK(frame.WrappingWidth() == view.contentsSize.width);
}

TEST_CASE(PREFIX "isAtTheBeginning/isAtTheEnd")
{
    SECTION("Full file window coverage")
    {
        SECTION("short")
        {
            const std::string data = "text1\n"
                                     "text2\n"
                                     "text3\n"
                                     "text4\n"
                                     "text5\n"
                                     "text6";
            Context ctx{data}; // NOLINT
            auto view = [[NCViewerTextModeView alloc] initWithFrame:g_500x100
                                                            backend:ctx.backend
                                                              theme:g_DummyTheme
                                               highlightingSettings:ctx.hl_settings
                                                 enableHighlighting:false];
            CHECK(view.isAtTheBeginning == true);
            CHECK(view.isAtTheEnd == true);
        }
        SECTION("long")
        {
            const std::string data = "text1\n"
                                     "text2\n"
                                     "text3\n"
                                     "text4\n"
                                     "text5\n"
                                     "text6\n"
                                     "text7\n";
            Context ctx{data}; // NOLINT
            auto view = [[NCViewerTextModeView alloc] initWithFrame:g_500x100
                                                            backend:ctx.backend
                                                              theme:g_DummyTheme
                                               highlightingSettings:ctx.hl_settings
                                                 enableHighlighting:false];
            CHECK(view.isAtTheBeginning == true);
            CHECK(view.isAtTheEnd == false);

            [view scrollToGlobalBytesOffset:data.size()];
            CHECK(view.isAtTheBeginning == false);
            CHECK(view.isAtTheEnd == true);
        }
    }
    SECTION("Partial file window coverage")
    {
        std::string lorem; // 64 * 2048 = 131072b long
        for( size_t i = 0; i != 2048; ++i )
            lorem += "Lorem ipsum dolor sit amet, consectetur adipiscing elit, sed do\n";
        Context ctx{lorem};
        REQUIRE(ctx.window->WindowSize() == 32768);
        auto delegate = [[NCViewerTextModeViewMockDelegate alloc] init];
        delegate.syncBackendWindowMovement = [&](NCViewerTextModeView *, int64_t _position) {
            return ctx.backend->MoveWindowSync(_position);
        };

        auto view = [[NCViewerTextModeView alloc] initWithFrame:g_500x100
                                                        backend:ctx.backend
                                                          theme:g_DummyTheme
                                           highlightingSettings:ctx.hl_settings
                                             enableHighlighting:false];
        view.delegate = delegate;
        CHECK(view.isAtTheBeginning == true);
        CHECK(view.isAtTheEnd == false);

        [view scrollToGlobalBytesOffset:lorem.size() / 2];

        CHECK(view.isAtTheBeginning == false);
        CHECK(view.isAtTheEnd == false);

        [view scrollToGlobalBytesOffset:lorem.size()];

        CHECK(view.isAtTheBeginning == false);
        CHECK(view.isAtTheEnd == true);
    }
}

TEST_CASE(PREFIX "attachToNewBackend")
{
    const std::string data1 = "text1\n"
                              "text2\n"
                              "text3\n"
                              "text4\n"
                              "text5\n"
                              "text6\n"
                              "text7\n";
    Context ctx{data1};
    auto view = [[NCViewerTextModeView alloc] initWithFrame:g_500x100
                                                    backend:ctx.backend
                                                      theme:g_DummyTheme
                                       highlightingSettings:ctx.hl_settings
                                         enableHighlighting:false];
    [view scrollToGlobalBytesOffset:data1.size()];
    CHECK(view.textFrame.LinesNumber() == 7);
    CHECK(view.isAtTheBeginning == false);
    CHECK(view.isAtTheEnd == true);

    SECTION("Smaller")
    {
        const std::string data2 = "text1\n"
                                  "text2\n"
                                  "text3\n";
        ctx.Reload(data2);
        [view attachToNewBackend:ctx.backend];
        [view scrollToGlobalBytesOffset:0];
        CHECK(view.textFrame.LinesNumber() == 3);
        CHECK(view.isAtTheBeginning == true);
        CHECK(view.isAtTheEnd == true);
    }
    SECTION("Empty")
    {
        const std::string data2;
        ctx.Reload(data2);
        [view attachToNewBackend:ctx.backend];
        [view scrollToGlobalBytesOffset:0]; // TODO: a view shouldn't need this!
        CHECK(view.textFrame.LinesNumber() == 0);
        CHECK(view.isAtTheBeginning == true);
        CHECK(view.isAtTheEnd == true);
    }
}

NSFont *DummyTheme::Font() const
{
    return g_MenloRegular13;
}

NSColor *DummyTheme::OverlayColor() const
{
    return NSColor.blackColor;
}

NSColor *DummyTheme::TextColor() const
{
    return NSColor.blackColor;
}

NSColor *DummyTheme::TextSyntaxCommentColor() const
{
    return NSColor.blackColor;
}

NSColor *DummyTheme::TextSyntaxPreprocessorColor() const
{
    return NSColor.blackColor;
}

NSColor *DummyTheme::TextSyntaxKeywordColor() const
{
    return NSColor.blackColor;
}

NSColor *DummyTheme::TextSyntaxOperatorColor() const
{
    return NSColor.blackColor;
}

NSColor *DummyTheme::TextSyntaxIdentifierColor() const
{
    return NSColor.blackColor;
}

NSColor *DummyTheme::TextSyntaxNumberColor() const
{
    return NSColor.blackColor;
}

NSColor *DummyTheme::TextSyntaxStringColor() const
{
    return NSColor.blackColor;
}

NSColor *DummyTheme::ViewerSelectionColor() const
{
    return NSColor.blackColor;
}

NSColor *DummyTheme::ViewerBackgroundColor() const
{
    return NSColor.blackColor;
}

void DummyTheme::ObserveChanges(std::function<void()> /*_callback*/)
{
}

Context::Context(std::string_view _string)
{
    Open(_string);
}

void Context::Open(std::string_view _string)
{
    file = std::make_shared<nc::vfs::GenericMemReadOnlyFile>("/foo.txt", nc::vfs::Host::DummyHost(), _string);
    file->Open(nc::vfs::Flags::OF_Read);
    window = std::make_shared<nc::vfs::FileWindow>(file);
    backend = std::make_shared<DataBackend>(window, nc::utility::Encoding::ENCODING_UTF8);
}

void Context::Reload(std::string_view _new_string)
{
    Open(_new_string);
}

@implementation NCViewerTextModeViewMockDelegate

@synthesize syncBackendWindowMovement;

- (std::expected<void, nc::Error>)textModeView:(NCViewerTextModeView *)_view
           requestsSyncBackendWindowMovementAt:(int64_t)_position
{
    assert(self.syncBackendWindowMovement);
    return self.syncBackendWindowMovement(_view, _position);
}

- (void)textModeView:(NCViewerTextModeView *)_view
    didScrollAtGlobalBytePosition:(int64_t)_position
             withScrollerPosition:(double)_scroller_position
{
}

- (void)textModeView:(NCViewerTextModeView *)_view setSelection:(CFRange)_selection
{
}

- (bool)textModeViewProvideLineWrapping:(NCViewerTextModeView *)_view
{
    return false;
}

- (CFRange)textModeViewProvideSelection:(NCViewerTextModeView *)_view
{
    return {};
}

@end
