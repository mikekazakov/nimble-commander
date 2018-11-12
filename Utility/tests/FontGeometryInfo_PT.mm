#include "UnitTests_main.h"
#include "FontExtras.h"
#include <Habanero/CFString.h>
#include <random>

using nc::utility::FontGeometryInfo;

static const auto g_RandomAlphabet = []{
    std::vector<char> chars;
    for( char i = 'a'; i <= 'z'; ++i )
        chars.emplace_back(i);
    for( char i = 'A'; i <= 'Z'; ++i )
        chars.emplace_back(i);    
    for( char i = '0'; i <= '9'; ++i )
        chars.emplace_back(i);
    return chars;    
}();

static std::mt19937 g_RndGen(std::random_device{}());

static CFStringRef MakeRandomString(int _length)
{    
    std::uniform_int_distribution<int> distribution(0, (int)g_RandomAlphabet.size() - 1);
    std::string str;
    while( _length --> 0  )
        str.push_back( g_RandomAlphabet[distribution(g_RndGen)] );
    return CFStringCreateWithUTF8StdString(str);
}

static std::vector<CFStringRef> MakeRandomStrings(int _amount, int _length)
{
    std::vector<CFStringRef> strings(_amount, nullptr);
    for( auto &str: strings )
        str = MakeRandomString(_length);
    return strings;
}

TEST_CASE("FontGeometryInfo::CalculateStringsWidths perf test", "[!benchmark]")
{
    const auto font = [NSFont systemFontOfSize:12.0];    
    const auto length = 30;
    
    {
        const auto strings = MakeRandomStrings(100, length);
        BENCHMARK( "100 strings" ) {
            FontGeometryInfo::CalculateStringsWidths(strings, font);
        }
    }        
    {
        const auto strings = MakeRandomStrings(1000, length);
        BENCHMARK( "1000 strings" ) {
            FontGeometryInfo::CalculateStringsWidths(strings, font);
        }
    }
    {
        const auto strings = MakeRandomStrings(10000, length);
        BENCHMARK( "10000 strings" ) {
            FontGeometryInfo::CalculateStringsWidths(strings, font);
        }            
    }
}
