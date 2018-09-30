#include "Tests.h"

#include "ConfigImpl.h"
#include "NonPersistentOverwritesStorage.h"

using nc::config::ConfigImpl;
using nc::config::NonPersistentOverwritesStorage;

static std::shared_ptr<NonPersistentOverwritesStorage> MakeDummyStorage();

TEST_CASE("Config accepts an empty defaults document")
{
    ConfigImpl config{"", MakeDummyStorage()};
}

TEST_CASE("Config accepts a valid defaults document")
{
    auto json = "{\"abra\":42}";
    ConfigImpl config{json, MakeDummyStorage()};
}

TEST_CASE("Config throws on ivalid defaults document")
{
    auto json = "{\"abra\":42";
    try {
        ConfigImpl config{json, MakeDummyStorage()};
        CHECK(false);
    }
    catch(...){
        CHECK(true);
    }
}

TEST_CASE("Config finds root-level objects")
{
    auto json = "{\"abra\":42}";
    ConfigImpl config{json, MakeDummyStorage()};

    CHECK( config.Has("abra") == true );
    CHECK( config.Has("abr") == false );
    CHECK( config.Has("abraa") == false );
    CHECK( config.Has("bra") == false );
    CHECK( config.Has("") == false );
    CHECK( config.Has("iohwfoiywgfouygsof") == false );
    CHECK( config.Has(".abra") == false );
    CHECK( config.Has("....abra") == false );    
    CHECK( config.Has("abra.") == false );
    CHECK( config.Has("abra....") == false );
    CHECK( config.Has(".") == false );
    CHECK( config.Has(".......") == false );
}

TEST_CASE("Config finds nested objects")
{
    auto json = "{\"abra\": {\"cadabra\": {\"alakazam\": 42} } }";
    ConfigImpl config{json, MakeDummyStorage()};

    CHECK( config.Has("abra") == true );
    CHECK( config.Has("abra.cadabra") == true );
    CHECK( config.Has("abra.cadabra.alakazam") == true );
    CHECK( config.Has("cadabra.alakazam") == false );
    CHECK( config.Has("alakazam") == false );
}

TEST_CASE("Config.Get returns a valid value or kNullType")
{
    auto json = "{\"abra\": {\"cadabra\": {\"alakazam\": 42} } }";
    ConfigImpl config{json, MakeDummyStorage()};
    
    CHECK( config.Get("abra").GetType() == rapidjson::Type::kObjectType );
    CHECK( config.Get("abra.cadabra").GetType() == rapidjson::Type::kObjectType );
    CHECK( config.Get("abra.cadabra.alakazam").GetType() == rapidjson::Type::kNumberType );
    CHECK( config.Get("abra.cadabra.alakazamiwhef").GetType() == rapidjson::Type::kNullType );
    CHECK( config.Get("").GetType() == rapidjson::Type::kNullType );
    CHECK( config.Get("oisjhcvpowhp").GetType() == rapidjson::Type::kNullType );
    CHECK( config.Get("!@#$$#^*^&(*&(^$%").GetType() == rapidjson::Type::kNullType );
    CHECK( config.Get("......").GetType() == rapidjson::Type::kNullType );
}

TEST_CASE("Config returns a valid boolean value or false")
{
    auto json = "{\"abra\": true, \"cadabra\": false, \"alakazam\": 42}";
    ConfigImpl config{json, MakeDummyStorage()};
    
    CHECK( config.GetBool("abra") == true );
    CHECK( config.GetBool("cadabra") == false );
    CHECK( config.GetBool("alakazam") == false );    
    CHECK( config.GetBool("foobar") == false );
}

TEST_CASE("Config returns a valid int value or 0")
{
    auto json = "{\"abra\": 17, \"cadabra\": -79.5, \"alakazam\": false}";
    ConfigImpl config{json, MakeDummyStorage()};
    
    CHECK( config.GetInt("abra") == 17 );
    CHECK( config.GetInt("cadabra") == -79 );
    CHECK( config.GetInt("alakazam") == 0 );    
    CHECK( config.GetInt("foobar") == 0 );
}

TEST_CASE("Config returns a valid string value or an empty string")
{
    auto json = "{\"abra\": \"abc\", \"cadabra\": \"\", \"alakazam\": 42}";
    ConfigImpl config{json, MakeDummyStorage()};
    
    CHECK( config.GetString("abra") == "abc" );
    CHECK( config.GetString("cadabra") == "" );
    CHECK( config.GetString("alakazam") == "" );    
    CHECK( config.GetString("foobar") == "" );
}

TEST_CASE("Config overwrites existing values with proper types and values")
{
    auto json = "{\"abra\": 42}";
    ConfigImpl config{json, MakeDummyStorage()};
    
    config.Set("abra", 17);
    CHECK( config.GetInt("abra") == 17 );
    
    config.Set("abra", "cadabra");
    CHECK( config.GetString("abra") == "cadabra" );

    config.Set("abra", true);
    CHECK( config.GetBool("abra") == true );
    
    config.Set("abra", false);
    CHECK( config.GetBool("abra") == false );
}

TEST_CASE("Config can overwrite nested values")
{
    auto json = "{\"abra\": {\"cadabra\": {\"alakazam\": 42} } }";
    ConfigImpl config{json, MakeDummyStorage()};

    config.Set("abra.cadabra.alakazam", 17);
    CHECK( config.GetInt("abra.cadabra.alakazam") == 17 );
}

TEST_CASE("Config can add new values")
{
    auto json = "{\"abra\": {\"cadabra\": {\"alakazam\": 42} } }";
    ConfigImpl config{json, MakeDummyStorage()};
    
    config.Set("abra.cadabra.alakazam2", 17);
    CHECK( config.GetInt("abra.cadabra.alakazam") == 42 );
    CHECK( config.GetInt("abra.cadabra.alakazam2") == 17 );    
}

TEST_CASE("Config ignores setting values with no valid root node")
{
    auto json = "{\"abra\": {\"cadabra\": {\"alakazam\": 42} } }";
    ConfigImpl config{json, MakeDummyStorage()};
    
    config.Set("abra.cadabr.alakazam", 17);
    config.Set("....cadabr.alakazam", 17);
    config.Set("abra.cadabra.alakazam....", 17);
    config.Set("abra.cadabra..alakazam", 17);
    config.Set("abra..cadabra.alakazam", 17);
    config.Set("", 17);
    CHECK( config.GetInt("abra.cadabra.alakazam") == 42 );    
}

TEST_CASE("Config does notify when value changed")
{
    auto json = "{\"abra\": {\"cadabra\": {\"alakazam\": 42} } }";
    ConfigImpl config{json, MakeDummyStorage()};

    int num_called = 0;
    config.ObserveForever("abra.cadabra.alakazam", [&]{ num_called++; });
    config.Set("abra.cadabra.alakazam", 17);
    CHECK( num_called == 1 );
}

TEST_CASE("Config notifies all observers when value changed")
{
    auto json = "{\"abra\": {\"cadabra\": {\"alakazam\": 42} } }";
    ConfigImpl config{json, MakeDummyStorage()};
    
    int num_called1 = 0;
    int num_called2 = 0;
    config.ObserveForever("abra.cadabra.alakazam", [&]{ num_called1++; });
    config.ObserveForever("abra.cadabra.alakazam", [&]{ num_called2++; });
    config.Set("abra.cadabra.alakazam", 17);
    CHECK( num_called1 == 1 );
    CHECK( num_called2 == 1 );
}

TEST_CASE("Config does notify when value was set to the same value")
{
    auto json = "{\"abra\": {\"cadabra\": {\"alakazam\": 42} } }";
    ConfigImpl config{json, MakeDummyStorage()};
    
    int num_called = 0;
    config.ObserveForever("abra.cadabra.alakazam", [&]{ num_called++; });
    config.Set("abra.cadabra.alakazam", 17);
    config.Set("abra.cadabra.alakazam", 17);
    CHECK( num_called == 1 );
}

TEST_CASE("Config does stop notifying when observation token dies")
{
    auto json = "{\"abra\": {\"cadabra\": {\"alakazam\": 42} } }";
    ConfigImpl config{json, MakeDummyStorage()};
    
    int num_called = 0;
    {
        const auto token = config.Observe("abra.cadabra.alakazam", [&]{ num_called++; });
        config.Set("abra.cadabra.alakazam", 17);
    }
    config.Set("abra.cadabra.alakazam", 18);
    CHECK( num_called == 1 );
}

static std::shared_ptr<NonPersistentOverwritesStorage> MakeDummyStorage()
{
    return std::make_shared<NonPersistentOverwritesStorage>("");
}
