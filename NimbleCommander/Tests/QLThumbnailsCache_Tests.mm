// Copyright (C) 2017 Michael Kazakov. Subject to GNU General Public License version 3.
#import <XCTest/XCTest.h>
#include <NimbleCommander/Core/Caches/QLThumbnailsCache.h>

static const char* g_Paths[] = {
"/Library/Desktop Pictures/Abstract Shapes.jpg",
"/Library/Desktop Pictures/Abstract.jpg",
"/Library/Desktop Pictures/Antelope Canyon.jpg",
"/Library/Desktop Pictures/Bahamas Aerial.jpg",
"/Library/Desktop Pictures/Beach.jpg",
"/Library/Desktop Pictures/Blue Pond.jpg",
"/Library/Desktop Pictures/Bristle Grass.jpg",
"/Library/Desktop Pictures/Brushes.jpg",
"/Library/Desktop Pictures/Circles.jpg",
"/Library/Desktop Pictures/Color Burst 1.jpg",
"/Library/Desktop Pictures/Color Burst 2.jpg",
"/Library/Desktop Pictures/Color Burst 3.jpg",
"/Library/Desktop Pictures/Death Valley.jpg",
"/Library/Desktop Pictures/Desert.jpg",
"/Library/Desktop Pictures/Ducks on a Misty Pond.jpg",
"/Library/Desktop Pictures/Eagle & Waterfall.jpg",
"/Library/Desktop Pictures/Earth and Moon.jpg",
"/Library/Desktop Pictures/Earth Horizon.jpg",
"/Library/Desktop Pictures/El Capitan 2.jpg",
"/Library/Desktop Pictures/El Capitan.jpg",
"/Library/Desktop Pictures/Elephant.jpg",
"/Library/Desktop Pictures/Flamingos.jpg",
"/Library/Desktop Pictures/Floating Ice.jpg",
"/Library/Desktop Pictures/Floating Leaves.jpg",
"/Library/Desktop Pictures/Foggy Forest.jpg",
"/Library/Desktop Pictures/Forest in Mist.jpg",
"/Library/Desktop Pictures/Foxtail Barley.jpg",
"/Library/Desktop Pictures/Frog.jpg",
"/Library/Desktop Pictures/Galaxy.jpg",
"/Library/Desktop Pictures/Grass Blades.jpg",
"/Library/Desktop Pictures/Hawaiian Print.jpg",
"/Library/Desktop Pictures/Isles.jpg",
"/Library/Desktop Pictures/Lake.jpg",
"/Library/Desktop Pictures/Lion.jpg",
"/Library/Desktop Pictures/Milky Way.jpg",
"/Library/Desktop Pictures/Moon.jpg",
"/Library/Desktop Pictures/Mountain Range.jpg",
"/Library/Desktop Pictures/Mt. Fuji.jpg",
"/Library/Desktop Pictures/Pink Forest.jpg",
"/Library/Desktop Pictures/Pink Lotus Flower.jpg",
"/Library/Desktop Pictures/Poppies.jpg",
"/Library/Desktop Pictures/Red Bells.jpg",
"/Library/Desktop Pictures/Rice Paddy.jpg",
"/Library/Desktop Pictures/Rolling Waves.jpg",
"/Library/Desktop Pictures/Shapes.jpg",
"/Library/Desktop Pictures/Sierra 2.jpg",
"/Library/Desktop Pictures/Sierra.jpg",
"/Library/Desktop Pictures/Sky.jpg",
"/Library/Desktop Pictures/Snow.jpg",
"/Library/Desktop Pictures/Underwater.jpg",
"/Library/Desktop Pictures/Wave.jpg",
"/Library/Desktop Pictures/Yosemite 2.jpg",
"/Library/Desktop Pictures/Yosemite 3.jpg",
"/Library/Desktop Pictures/Yosemite 4.jpg",
"/Library/Desktop Pictures/Yosemite 5.jpg",
"/Library/Desktop Pictures/Yosemite.jpg",
"/Library/Desktop Pictures/Zebras.jpg",
"/Library/Screen Savers/Default Collections/1-National Geographic/NatGeo01.jpg",
"/Library/Screen Savers/Default Collections/1-National Geographic/NatGeo02.jpg",
"/Library/Screen Savers/Default Collections/1-National Geographic/NatGeo03.jpg",
"/Library/Screen Savers/Default Collections/1-National Geographic/NatGeo04.jpg",
"/Library/Screen Savers/Default Collections/1-National Geographic/NatGeo05.jpg",
"/Library/Screen Savers/Default Collections/1-National Geographic/NatGeo06.jpg",
"/Library/Screen Savers/Default Collections/1-National Geographic/NatGeo07.jpg",
"/Library/Screen Savers/Default Collections/1-National Geographic/NatGeo08.jpg",
"/Library/Screen Savers/Default Collections/1-National Geographic/NatGeo09.jpg",
"/Library/Screen Savers/Default Collections/1-National Geographic/NatGeo10.jpg",
"/Library/Screen Savers/Default Collections/1-National Geographic/NatGeo11.jpg",
"/Library/Screen Savers/Default Collections/1-National Geographic/NatGeo12.jpg",
"/Library/Screen Savers/Default Collections/1-National Geographic/NatGeo13.jpg",
"/Library/Screen Savers/Default Collections/1-National Geographic/NatGeo14.jpg",
"/Library/Screen Savers/Default Collections/1-National Geographic/NatGeo15.jpg",
"/Library/Screen Savers/Default Collections/1-National Geographic/NatGeo16.jpg",
"/Library/Screen Savers/Default Collections/1-National Geographic/NatGeo17.jpg",
"/Library/Screen Savers/Default Collections/2-Aerial/Aerial01.jpg",
"/Library/Screen Savers/Default Collections/2-Aerial/Aerial02.jpg",
"/Library/Screen Savers/Default Collections/2-Aerial/Aerial03.jpg",
"/Library/Screen Savers/Default Collections/2-Aerial/Aerial06.jpg",
"/Library/Screen Savers/Default Collections/2-Aerial/Aerial07.jpg",
"/Library/Screen Savers/Default Collections/2-Aerial/Aerial08.jpg",
"/Library/Screen Savers/Default Collections/2-Aerial/Aerial09.jpg",
"/Library/Screen Savers/Default Collections/3-Cosmos/Cosmos01.jpg",
"/Library/Screen Savers/Default Collections/3-Cosmos/Cosmos02.jpg",
"/Library/Screen Savers/Default Collections/3-Cosmos/Cosmos03.jpg",
"/Library/Screen Savers/Default Collections/3-Cosmos/Cosmos04.jpg",
"/Library/Screen Savers/Default Collections/3-Cosmos/Cosmos05.jpg",
"/Library/Screen Savers/Default Collections/3-Cosmos/Cosmos07.jpg",
"/Library/Screen Savers/Default Collections/3-Cosmos/Cosmos08.jpg",
"/Library/Screen Savers/Default Collections/3-Cosmos/Cosmos09.jpg",
"/Library/Screen Savers/Default Collections/4-Nature Patterns/NaturePatterns01.jpg",
"/Library/Screen Savers/Default Collections/4-Nature Patterns/NaturePatterns02.jpg",
"/Library/Screen Savers/Default Collections/4-Nature Patterns/NaturePatterns03.jpg",
"/Library/Screen Savers/Default Collections/4-Nature Patterns/NaturePatterns05.jpg",
"/Library/Screen Savers/Default Collections/4-Nature Patterns/NaturePatterns06.jpg",
"/Library/Screen Savers/Default Collections/4-Nature Patterns/NaturePatterns07.jpg",
"/Library/Screen Savers/Default Collections/4-Nature Patterns/NaturePatterns08.jpg"
};

@interface QLThumbnailsCache_Tests : XCTestCase

@end


@implementation QLThumbnailsCache_Tests

- (void)testConcurrentAccess
{
    for( int i = 0; i < 10; ++i ) {
        dispatch_apply( size(g_Paths),
                       dispatch_get_global_queue(QOS_CLASS_UTILITY, 0),
                       [](size_t index){
                           auto &qlc = QLThumbnailsCache::Instance();
                           qlc.ThumbnailIfHas(g_Paths[index], 32);
                           qlc.ProduceThumbnail(g_Paths[index], 32);
                       });
    }

    XCTAssert( true );
}

@end
