// Copyright (C) 2018-2023 Michael Kazakov. Subject to GNU General Public License version 3.
#include <Base/LRUCache.h>
#include "UnitTests_main.h"
#include <string>

using nc::base::LRUCache;

#define PREFIX "LRUCache "

TEST_CASE(PREFIX "empty")
{
    const LRUCache<std::string, std::string, 32> cache;
    CHECK(cache.size() == 0); // NOLINT
    CHECK(cache.max_size() == 32);
    CHECK(cache.empty() == true);
}

TEST_CASE(PREFIX "insertion")
{
    LRUCache<std::string, std::string, 5> cache;
    cache.insert("a", "A");
    cache.insert("b", "B");
    cache.insert("c", "C");
    cache.insert("d", "D");
    cache.insert("e", "E");
    CHECK(cache.size() == 5);
    CHECK(cache.count("a") == 1);
    CHECK(cache.count("b") == 1);
    CHECK(cache.count("c") == 1);
    CHECK(cache.count("d") == 1);
    CHECK(cache.count("e") == 1);

    CHECK(cache.at("a") == "A");
    CHECK(cache.at("b") == "B");
    CHECK(cache.at("c") == "C");
    CHECK(cache.at("d") == "D");
    CHECK(cache.at("e") == "E");
}

TEST_CASE(PREFIX "bracket insertion")
{
    LRUCache<std::string, std::string, 5> cache;
    cache["a"] = "A";
    cache["b"] = "B";
    cache["c"] = "C";
    cache["d"] = "D";
    cache["e"] = "E";
    CHECK(cache.size() == 5);

    CHECK(cache["a"] == "A");
    CHECK(cache["b"] == "B");
    CHECK(cache["c"] == "C");
    CHECK(cache["d"] == "D");
    CHECK(cache["e"] == "E");
}

TEST_CASE(PREFIX "eviction")
{
    LRUCache<std::string, std::string, 2> cache;
    cache["a"] = "A";
    cache["b"] = "B";
    cache["c"] = "C";
    CHECK(cache.count("a") == 0);
    CHECK(cache.count("b") == 1);
    CHECK(cache.count("c") == 1);

    (void)cache["b"];
    cache["a"] = "A";
    CHECK(cache.count("a") == 1);
    CHECK(cache.count("b") == 1);
    CHECK(cache.count("c") == 0);
}

TEST_CASE(PREFIX "copy")
{
    // NOLINTBEGIN(bugprone-use-after-move)
    LRUCache<std::string, std::string, 2> cache;
    cache["a"] = "A";
    cache["b"] = "B";

    LRUCache<std::string, std::string, 2> copy(cache);
    CHECK(cache.size() == 2);
    CHECK(copy["a"] == "A");
    CHECK(copy["b"] == "B");

    LRUCache<std::string, std::string, 2> copy2(std::move(cache));
    CHECK(cache.empty() == true);
    CHECK(copy2["a"] == "A");
    CHECK(copy2["b"] == "B");

    cache = copy2;
    CHECK(copy2.size() == 2);
    CHECK(cache["a"] == "A");
    CHECK(cache["b"] == "B");

    copy = std::move(copy2);
    CHECK(copy2.empty() == true);
    CHECK(copy["a"] == "A");
    CHECK(copy["b"] == "B");
    // NOLINTEND(bugprone-use-after-move)
}

TEST_CASE(PREFIX "big cache")
{
    const int limit = 1'000'000;
    LRUCache<int, int, limit> cache;
    for( int i = 0; i < limit; ++i )
        cache[i] = -1;
    for( int i = limit - 1; i >= 0; --i ) {
        if( cache[i] != -1 ) {
            CHECK(cache[i] == -1);
        }
    }

    cache[limit] = -1;
    CHECK(cache.count(limit - 1) == 0);
}
