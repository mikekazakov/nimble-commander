// Copyright (C) 2025 Michael Kazakov. Subject to GNU General Public License version 3.
#include "PanelGalleryCentralView.h"
#include <Utility/UTI.h>
#include <Utility/ExtensionLowercaseComparison.h>
#include <Utility/StringExtras.h>
#include <Utility/PathManip.h>
#include <Base/dispatch_cpp.h>
#include <Quartz/Quartz.h>

@implementation NCPanelGalleryCentralView {
    const nc::utility::UTIDB *m_UTIDB;
    QLPreviewView *m_QLView;
    NSImageView *m_FallbackImageView;
    std::filesystem::path m_FallbackImagePath; // ??

    // It's a workaround for the macOS bug reported in FB9809109/FB5352643.
    bool m_CurrentPreviewIsHazardous;
    std::optional<nc::utility::ExtensionsLowercaseList> m_HazardousExtsList; // empty means everything is hazardous
}

- (instancetype)initWithFrame:(NSRect)_frame
                        UTIDB:(const nc::utility::UTIDB &)_UTIDB
    QLHazardousExtensionsList:(const std::string &)_ql_hazard_list
{
    dispatch_assert_main_queue();
    self = [super initWithFrame:_frame];
    if( !self )
        return nil;
    m_UTIDB = &_UTIDB;
    m_CurrentPreviewIsHazardous = false;

    self.translatesAutoresizingMaskIntoConstraints = false;

    m_QLView = [[QLPreviewView alloc] initWithFrame:_frame style:QLPreviewViewStyleNormal];
    m_QLView.translatesAutoresizingMaskIntoConstraints = false;
    [self addSubview:m_QLView];

    m_FallbackImageView = [[NSImageView alloc] initWithFrame:_frame];
    m_FallbackImageView.translatesAutoresizingMaskIntoConstraints = false;
    m_FallbackImageView.imageScaling = NSImageScaleProportionallyUpOrDown;
    m_FallbackImageView.hidden = true;
    [self addSubview:m_FallbackImageView];

    const auto views_dict = NSDictionaryOfVariableBindings(m_QLView, m_FallbackImageView);
    const auto add_constraints = [&](NSString *_vis_fmt) {
        const auto constraints = [NSLayoutConstraint constraintsWithVisualFormat:_vis_fmt
                                                                         options:0
                                                                         metrics:nil
                                                                           views:views_dict];
        [self addConstraints:constraints];
    };
    add_constraints(@"|-(0)-[m_QLView]-(0)-|");
    add_constraints(@"|-(0)-[m_FallbackImageView]-(0)-|");
    add_constraints(@"V:|-(0)-[m_QLView]-(0)-|");
    add_constraints(@"V:|-(0)-[m_FallbackImageView]-(0)-|");

    if( _ql_hazard_list != "*" ) {
        m_HazardousExtsList.emplace(_ql_hazard_list);
    }

    return self;
}

- (void)showVFSItem:(VFSListingItem)_item
{
    dispatch_assert_main_queue();

    // For now only supporting native vfs
    if( _item && _item.Host()->IsNativeFS() ) {
        const std::string path = _item.Path();
        if( NSString *ns_path = [NSString stringWithUTF8StdString:path] ) {
            if( NSURL *url = [NSURL fileURLWithPath:ns_path] ) {
                if( [self couldBeSupportedByQuickLook:_item] ) {
                    m_QLView.hidden = false;
                    m_FallbackImageView.hidden = true;
                    m_FallbackImagePath = "";
                    if( m_CurrentPreviewIsHazardous ) {
                        m_QLView.previewItem =
                            nil; // to prevent an ObjC exception from inside QL - reset the view first
                    }
                    m_QLView.previewItem = url;
                }
                else {
                    m_QLView.hidden = true;
                    m_QLView.previewItem =
                        nil; // NB! Without resetting the preview to nil, it somehow manages to completely freeze
                    m_FallbackImageView.hidden = false;

                    // TODO: never call this in the main thread
                    if( m_FallbackImagePath != path ) {
                        // fmt::println("Gallery fallback image for path: {}", path);
                        m_FallbackImageView.image = [[NSWorkspace sharedWorkspace] iconForFile:ns_path];
                        m_FallbackImagePath = path;
                    }
                }
                m_CurrentPreviewIsHazardous = [self isHazardousPath:path];
            }
        }
    }
}

- (bool)couldBeSupportedByQuickLook:(const VFSListingItem &)_item
{
    if( !_item.HasExtension() ) {
        // No extensions -> no UTI mapping -> no QL generator / preview appex / thumbnail appex can support it
        return false;
    }

    const std::string_view extension = _item.Extension();
    if( extension == "app" ) {
        return false; // QL cannot preview .app bundles, leave it to NSWorkspace
    }

    // Anything permanently registered in the system can be theoretically supported by QL
    const std::string uti = m_UTIDB->UTIForExtension(extension);
    return m_UTIDB->IsDeclaredUTI(uti);
}

- (bool)isHazardousPath:(std::string_view)_path
{
    if( m_HazardousExtsList == std::nullopt )
        return true;
    return m_HazardousExtsList->contains(nc::utility::PathManip::Extension(_path));
}

@end
