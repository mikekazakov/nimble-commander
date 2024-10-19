// Copyright (C) 2018-2024 Michael Kazakov. Subject to GNU General Public License version 3.
#include "Tests.h"

#include "ConfigImpl.h"
#include "NonPersistentOverwritesStorage.h"

using nc::config::ConfigImpl;
using nc::config::NonPersistentOverwritesStorage;
using nc::config::Token;

static std::shared_ptr<NonPersistentOverwritesStorage> MakeDummyStorage();
static std::shared_ptr<NonPersistentOverwritesStorage> MakeDummyStorage(std::string_view _value);

TEST_CASE("Config accepts an empty defaults document")
{
    const ConfigImpl config{"", MakeDummyStorage()};
}

TEST_CASE("Config accepts a valid defaults document")
{
    auto json = "{\"abra\":42}";
    const ConfigImpl config{json, MakeDummyStorage()};
}

TEST_CASE("Config throws on ivalid defaults document")
{
    auto json = "{\"abra\":42";
    try {
        const ConfigImpl config{json, MakeDummyStorage()};
        CHECK(false);
    } catch( ... ) {
        CHECK(true);
    }
}

TEST_CASE("Config finds root-level objects")
{
    auto json = "{\"abra\":42}";
    const ConfigImpl config{json, MakeDummyStorage()};

    CHECK(config.Has("abra") == true);
    CHECK(config.Has("abr") == false);
    CHECK(config.Has("abraa") == false);
    CHECK(config.Has("bra") == false);
    CHECK(config.Has("") == false);
    CHECK(config.Has("iohwfoiywgfouygsof") == false);
    CHECK(config.Has(".abra") == false);
    CHECK(config.Has("....abra") == false);
    CHECK(config.Has("abra.") == false);
    CHECK(config.Has("abra....") == false);
    CHECK(config.Has(".") == false);
    CHECK(config.Has(".......") == false);
}

TEST_CASE("Config finds nested objects")
{
    auto json = R"({"abra": {"cadabra": {"alakazam": 42} } })";
    const ConfigImpl config{json, MakeDummyStorage()};

    CHECK(config.Has("abra") == true);
    CHECK(config.Has("abra.cadabra") == true);
    CHECK(config.Has("abra.cadabra.alakazam") == true);
    CHECK(config.Has("cadabra.alakazam") == false);
    CHECK(config.Has("alakazam") == false);
}

TEST_CASE("Config.Get returns a valid value or kNullType")
{
    auto json = R"({"abra": {"cadabra": {"alakazam": 42} } })";
    const ConfigImpl config{json, MakeDummyStorage()};

    CHECK(config.Get("abra").GetType() == rapidjson::Type::kObjectType);
    CHECK(config.Get("abra.cadabra").GetType() == rapidjson::Type::kObjectType);
    CHECK(config.Get("abra.cadabra.alakazam").GetType() == rapidjson::Type::kNumberType);
    CHECK(config.Get("abra.cadabra.alakazamiwhef").GetType() == rapidjson::Type::kNullType);
    CHECK(config.Get("").GetType() == rapidjson::Type::kNullType);
    CHECK(config.Get("oisjhcvpowhp").GetType() == rapidjson::Type::kNullType);
    CHECK(config.Get("!@#$$#^*^&(*&(^$%").GetType() == rapidjson::Type::kNullType);
    CHECK(config.Get("......").GetType() == rapidjson::Type::kNullType);
}

TEST_CASE("Config returns a valid boolean value or false")
{
    auto json = R"({"abra": true, "cadabra": false, "alakazam": 42})";
    const ConfigImpl config{json, MakeDummyStorage()};

    CHECK(config.GetBool("abra") == true);
    CHECK(config.GetBool("cadabra") == false);
    CHECK(config.GetBool("alakazam") == false);
    CHECK(config.GetBool("foobar") == false);
}

TEST_CASE("Config returns a valid int value or 0")
{
    auto json = R"({"abra": 17, "cadabra": -79.5, "alakazam": false})";
    const ConfigImpl config{json, MakeDummyStorage()};

    CHECK(config.GetInt("abra") == 17);
    CHECK(config.GetInt("cadabra") == -79);
    CHECK(config.GetInt("alakazam") == 0);
    CHECK(config.GetInt("foobar") == 0);
}

TEST_CASE("Config returns a valid string value or an empty string")
{
    auto json = R"({"abra": "abc", "cadabra": "", "alakazam": 42})";
    const ConfigImpl config{json, MakeDummyStorage()};

    CHECK(config.GetString("abra") == "abc");
    CHECK(config.GetString("cadabra").empty());
    CHECK(config.GetString("alakazam").empty());
    CHECK(config.GetString("foobar").empty());
}

TEST_CASE("Config overwrites existing values with proper types and values")
{
    auto json = "{\"abra\": 42}";
    ConfigImpl config{json, MakeDummyStorage()};

    config.Set("abra", 17);
    CHECK(config.GetInt("abra") == 17);

    config.Set("abra", "cadabra");
    CHECK(config.GetString("abra") == "cadabra");

    config.Set("abra", true);
    CHECK(config.GetBool("abra") == true);

    config.Set("abra", false);
    CHECK(config.GetBool("abra") == false);
}

TEST_CASE("Config can overwrite nested values")
{
    auto json = R"({"abra": {"cadabra": {"alakazam": 42} } })";
    ConfigImpl config{json, MakeDummyStorage()};

    config.Set("abra.cadabra.alakazam", 17);
    CHECK(config.GetInt("abra.cadabra.alakazam") == 17);
}

TEST_CASE("Config can add new values")
{
    auto json = R"({"abra": {"cadabra": {"alakazam": 42} } })";
    ConfigImpl config{json, MakeDummyStorage()};

    config.Set("abra.cadabra.alakazam2", 17);
    CHECK(config.GetInt("abra.cadabra.alakazam") == 42);
    CHECK(config.GetInt("abra.cadabra.alakazam2") == 17);
}

TEST_CASE("Config ignores setting values with no valid root node")
{
    auto json = R"({"abra": {"cadabra": {"alakazam": 42} } })";
    ConfigImpl config{json, MakeDummyStorage()};

    config.Set("abra.cadabr.alakazam", 17);
    config.Set("....cadabr.alakazam", 17);
    config.Set("abra.cadabra.alakazam....", 17);
    config.Set("abra.cadabra..alakazam", 17);
    config.Set("abra..cadabra.alakazam", 17);
    config.Set("", 17);
    CHECK(config.GetInt("abra.cadabra.alakazam") == 42);
}

TEST_CASE("Config does notify when value changed")
{
    auto json = R"({"abra": {"cadabra": {"alakazam": 42} } })";
    ConfigImpl config{json, MakeDummyStorage()};

    int num_called = 0;
    config.ObserveForever("abra.cadabra.alakazam", [&] { num_called++; });
    config.Set("abra.cadabra.alakazam", 17);
    CHECK(num_called == 1);
}

TEST_CASE("Config notifies all observers when value changed")
{
    auto json = R"({"abra": {"cadabra": {"alakazam": 42} } })";
    ConfigImpl config{json, MakeDummyStorage()};

    int num_called1 = 0;
    int num_called2 = 0;
    config.ObserveForever("abra.cadabra.alakazam", [&] { num_called1++; });
    config.ObserveForever("abra.cadabra.alakazam", [&] { num_called2++; });
    config.Set("abra.cadabra.alakazam", 17);
    CHECK(num_called1 == 1);
    CHECK(num_called2 == 1);
}

TEST_CASE("Config does notify when value was set to the same value")
{
    auto json = R"({"abra": {"cadabra": {"alakazam": 42} } })";
    ConfigImpl config{json, MakeDummyStorage()};

    int num_called = 0;
    config.ObserveForever("abra.cadabra.alakazam", [&] { num_called++; });
    config.Set("abra.cadabra.alakazam", 17);
    config.Set("abra.cadabra.alakazam", 17);
    CHECK(num_called == 1);
}

TEST_CASE("Config does stop notifying when observation token dies")
{
    auto json = R"({"abra": {"cadabra": {"alakazam": 42} } })";
    ConfigImpl config{json, MakeDummyStorage()};

    int num_called = 0;
    {
        const auto token = config.Observe("abra.cadabra.alakazam", [&] { num_called++; });
        config.Set("abra.cadabra.alakazam", 17);
    }
    config.Set("abra.cadabra.alakazam", 18);
    CHECK(num_called == 1);
}

TEST_CASE("Config can remove an obsever from its own execution")
{
    auto json = "{\"abra\": 42}";
    ConfigImpl config{json, MakeDummyStorage()};
    Token *token = new Token(config.Observe("abra", [&] { delete token; }));
    config.Set("abra", 17);
}

TEST_CASE("Config returns overwritten values")
{
    auto json1 = "{\"abra\": 42}";
    auto json2 = "{\"abra\": 80}";
    const ConfigImpl config{json1, MakeDummyStorage(json2)};
    CHECK(config.GetInt("abra") == 80);
}

TEST_CASE("Config can returns default values when an overwrite exists")
{
    auto json1 = "{\"abra\": 42}";
    auto json2 = "{\"abra\": 80}";
    const ConfigImpl config{json1, MakeDummyStorage(json2)};
    REQUIRE(config.GetDefault("abra").GetType() == rapidjson::Type::kNumberType);
    CHECK(config.GetDefault("abra").GetInt() == 42);
}

TEST_CASE("Config returns overwritten nested values")
{
    auto json1 = R"({"abra": {"cadabra": {"alakazam": 42} } })";
    auto json2 = R"({"abra": {"cadabra": {"alakazam": 17} } })";
    const ConfigImpl config{json1, MakeDummyStorage(json2)};
    CHECK(config.GetInt("abra.cadabra.alakazam") == 17);
}

TEST_CASE("Config overwrites can add a new entry")
{
    auto json1 = "{\"abra\": 42}";
    auto json2 = "{\"abra1\": 80}";
    const ConfigImpl config{json1, MakeDummyStorage(json2)};
    CHECK(config.GetInt("abra") == 42);
    CHECK(config.GetInt("abra1") == 80);
}

TEST_CASE("Config overwrites can add a new nested entry")
{
    auto json1 = "{\"abra\": 42}";
    auto json2 = R"({"abra1": {"cadabra": {"alakazam": 90} } })";
    const ConfigImpl config{json1, MakeDummyStorage(json2)};
    CHECK(config.GetInt("abra1.cadabra.alakazam") == 90);
}

TEST_CASE("Config overwrites can change an entry type")
{
    auto json1 = "{\"abra\": 42}";
    auto json2 = R"({"abra": "ttt"})";
    const ConfigImpl config{json1, MakeDummyStorage(json2)};
    CHECK(config.GetString("abra") == "ttt");
}

TEST_CASE("Config overwrites can change an entry type even to object type")
{
    auto json1 = "{\"abra\": 42}";
    auto json2 = R"({"abra": {"cadabra": {"alakazam": 90} } })";
    const ConfigImpl config{json1, MakeDummyStorage(json2)};
    CHECK(config.GetInt("abra.cadabra.alakazam") == 90);
}

TEST_CASE("Config ignores broken overwrites data")
{
    auto json1 = "{\"abra\": 42}";
    auto json2 = "sodfbjosbfljsegfogw!@@#%$**&(";
    const ConfigImpl config{json1, MakeDummyStorage(json2)};
    CHECK(config.GetInt("abra") == 42);
}

TEST_CASE("Config saves overwrites")
{
    auto json = R"({"abra": {"cadabra": {"alakazam": 42} } })";
    auto storage = std::make_shared<NonPersistentOverwritesStorage>("");

    {
        ConfigImpl config{json, storage};
        config.Set("abra.cadabra.alakazam", 17);
    }
    {
        const ConfigImpl config{json, storage};
        CHECK(config.GetInt("abra.cadabra.alakazam") == 17);
    }
}

TEST_CASE("Config saves overwritten entries which are absent in defaults")
{
    auto json1 = R"({"abra": {"cadabra": {"alakazam": 42} } })";
    auto json2 = R"({"abra2": {"cadabra": {"alakazam": 50} } })";
    auto storage = std::make_shared<NonPersistentOverwritesStorage>(json2);

    {
        ConfigImpl config{json1, storage};
        config.Set("abra2.cadabra.alakazam", 17);
    }
    {
        const ConfigImpl config{json1, storage};
        CHECK(config.GetInt("abra2.cadabra.alakazam") == 17);
    }
}

TEST_CASE("Config can revert to default values")
{
    auto json1 = R"({"abra": {"cadabra": {"alakazam": 42} } })";
    auto json2 = R"({"abra": {"cadabra": {"alakazam": 17} } })";
    ConfigImpl config{json1, MakeDummyStorage(json2)};
    CHECK(config.GetInt("abra.cadabra.alakazam") == 17);
    config.ResetToDefaults();
    CHECK(config.GetInt("abra.cadabra.alakazam") == 42);
}

TEST_CASE("Config calls observers when reverting to default values")
{
    auto json1 = R"({"abra": {"cadabra": {"alakazam": 42} } })";
    auto json2 = R"({"abra": {"cadabra": {"alakazam": 17} } })";
    ConfigImpl config{json1, MakeDummyStorage(json2)};
    int num_called = 0;
    config.ObserveForever("abra.cadabra.alakazam", [&] { num_called++; });
    config.ResetToDefaults();
    CHECK(num_called == 1);
}

TEST_CASE("Config calls observers for absent entries when reverting to default values")
{
    auto json1 = "{}";
    auto json2 = R"({"abra": {"cadabra": {"alakazam": 17} } })";
    ConfigImpl config{json1, MakeDummyStorage(json2)};
    int num_called = 0;
    config.ObserveForever("abra.cadabra.alakazam", [&] { num_called++; });
    config.ResetToDefaults();
    CHECK(num_called == 1);
}

TEST_CASE("Config calls observers for added entries when reverting to default values")
{
    auto json1 = R"({"abra": {"cadabra": {"alakazam": 17} } })";
    auto json2 = "{\"abra\": 42}";
    ConfigImpl config{json1, MakeDummyStorage(json2)};
    int num_called = 0;
    config.ObserveForever("abra", [&] { num_called++; });
    config.ObserveForever("abra.cadabra", [&] { num_called++; });
    config.ObserveForever("abra.cadabra.alakazam", [&] { num_called++; });
    config.ResetToDefaults();
    CHECK(num_called == 3);
}

TEST_CASE("Config reloads externally changed overwrites")
{
    auto json1 = R"({"abra": {"cadabra": {"alakazam": 42} } })";
    auto json2 = R"({"abra": {"cadabra": {"alakazam": 17} } })";
    auto storage = std::make_shared<NonPersistentOverwritesStorage>(json2);
    ConfigImpl config{json1, storage};
    int num_called = 0;
    config.ObserveForever("abra.cadabra.alakazam", [&] { num_called++; });
    auto json3 = R"({"abra": {"cadabra": {"alakazam": 55} } })";
    storage->ExternalWrite(json3);
    CHECK(num_called == 1);
    CHECK(config.GetInt("abra.cadabra.alakazam") == 55);
}

static std::shared_ptr<NonPersistentOverwritesStorage> MakeDummyStorage()
{
    return MakeDummyStorage("");
}

static std::shared_ptr<NonPersistentOverwritesStorage> MakeDummyStorage(std::string_view _value)
{
    return std::make_shared<NonPersistentOverwritesStorage>(_value);
}
