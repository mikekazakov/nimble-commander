// Copyright (C) 2024 Michael Kazakov. Subject to GNU General Public License version 3.
#include <sys/dirent.h>
#include <VFS/VFS.h>
#include <VFS/VFSListingInput.h>
#include "UI/TagsPresentation.h"
#include "../Tests.h"

#define PREFIX "TagsPresentation "

using namespace nc;
using namespace nc::base;
using namespace nc::panel;
using utility::Tags;

TEST_CASE(PREFIX "TrailingTagsInplaceDisplay::Place")
{
    using Tag = Tags::Tag;
    using C = Tags::Color;
    constexpr int D = TrailingTagsInplaceDisplay::Diameter;
    constexpr int S = TrailingTagsInplaceDisplay::Step;
    constexpr int M = TrailingTagsInplaceDisplay::Margin;
    const std::string l = "doesnt matter";
    struct TC {
        std::vector<Tag> tags;
        int exp_width = 0;
        int exp_margin = 0;
    } const tcs[] = {
        {{}, 0, 0},
        {{Tag(&l, C::None)}, 0, 0},
        {{Tag(&l, C::Blue)}, D, M},
        {{Tag(&l, C::None), Tag(&l, C::None)}, 0, 0},
        {{Tag(&l, C::None), Tag(&l, C::None), Tag(&l, C::None)}, 0, 0},
        {{Tag(&l, C::None), Tag(&l, C::Blue)}, D, M},
        {{Tag(&l, C::Blue), Tag(&l, C::None)}, D, M},
        {{Tag(&l, C::None), Tag(&l, C::Blue), Tag(&l, C::None)}, D, M},
        {{Tag(&l, C::Blue), Tag(&l, C::Blue)}, D + S, M},
        {{Tag(&l, C::Blue), Tag(&l, C::None), Tag(&l, C::Blue)}, D + S, M},
        {{Tag(&l, C::None), Tag(&l, C::Blue), Tag(&l, C::Blue)}, D + S, M},
        {{Tag(&l, C::Blue), Tag(&l, C::Blue), Tag(&l, C::None)}, D + S, M},
        {{Tag(&l, C::None), Tag(&l, C::Blue), Tag(&l, C::Blue), Tag(&l, C::None)}, D + S, M},
        {{Tag(&l, C::Blue), Tag(&l, C::Blue), Tag(&l, C::Blue)}, D + S + S, M},
        {{Tag(&l, C::Blue), Tag(&l, C::Blue), Tag(&l, C::Blue), Tag(&l, C::Blue)}, D + S + S, M},
        {{Tag(&l, C::Blue), Tag(&l, C::None), Tag(&l, C::Blue), Tag(&l, C::Blue), Tag(&l, C::Blue)}, D + S + S, M}};
    for( const auto &tc : tcs ) {
        auto geom = TrailingTagsInplaceDisplay::Place(tc.tags);
        CHECK(geom.width == tc.exp_width);
        CHECK(geom.margin == tc.exp_margin);
    }
}
