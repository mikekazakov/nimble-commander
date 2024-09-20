// Copyright (C) 2018-2024 Michael Kazakov. Subject to GNU General Public License version 3.
#include "Tests.h"

#include "ObjCBridge.h"
#include "ConfigImpl.h"
#include "NonPersistentOverwritesStorage.h"

using nc::config::ConfigImpl;
using nc::config::NonPersistentOverwritesStorage;

static std::shared_ptr<NonPersistentOverwritesStorage> MakeDummyStorage();
static std::shared_ptr<NonPersistentOverwritesStorage> MakeDummyStorage(std::string_view _value);

TEST_CASE("ConfigBridge returns a valid value")
{
    auto json = "{\"abra\":42}";
    ConfigImpl config{json, MakeDummyStorage()}; // NOLINT
    auto bridge = [[NCConfigObjCBridge alloc] initWithConfig:config];

    const id value = [bridge valueForKeyPath:@"abra"];
    CHECK(static_cast<NSNumber *>(value).intValue == 42);
}

TEST_CASE("ConfigBridge returns a valid value from a nested value")
{
    auto json = R"({"abra": {"cadabra": {"alakazam": "Hello"} } })";
    ConfigImpl config{json, MakeDummyStorage()}; // NOLINT
    auto bridge = [[NCConfigObjCBridge alloc] initWithConfig:config];

    const id value = [bridge valueForKeyPath:@"abra.cadabra.alakazam"];
    CHECK([static_cast<NSString *>(value) isEqualToString:@"Hello"]);
}

TEST_CASE("ConfigBridge returns nil for an invalid path")
{
    auto json = "{\"abra\":42}";
    ConfigImpl config{json, MakeDummyStorage()}; // NOLINT
    auto bridge = [[NCConfigObjCBridge alloc] initWithConfig:config];

    const id value = [bridge valueForKeyPath:@"abra1"];
    CHECK(value == nil);
}

TEST_CASE("ConfigBridge can change a nested value")
{
    auto json = R"({"abra": {"cadabra": {"alakazam": "Hello"} } })";
    ConfigImpl config{json, MakeDummyStorage()}; // NOLINT
    auto bridge = [[NCConfigObjCBridge alloc] initWithConfig:config];

    [bridge setValue:@42 forKeyPath:@"abra.cadabra.alakazam"];
    CHECK(config.GetInt("abra.cadabra.alakazam") == 42);
}

TEST_CASE("ConfigBridge can set boolean values")
{
    auto json = "{\"abra\": 42}";
    ConfigImpl config{json, MakeDummyStorage()}; // NOLINT
    auto bridge = [[NCConfigObjCBridge alloc] initWithConfig:config];

    [bridge setValue:@YES forKeyPath:@"abra"];
    CHECK(config.GetBool("abra") == true);

    [bridge setValue:@NO forKeyPath:@"abra"];
    CHECK(config.GetBool("abra") == false);
}

static std::shared_ptr<NonPersistentOverwritesStorage> MakeDummyStorage()
{
    return MakeDummyStorage("");
}

static std::shared_ptr<NonPersistentOverwritesStorage> MakeDummyStorage(std::string_view _value)
{
    return std::make_shared<NonPersistentOverwritesStorage>(_value);
}
