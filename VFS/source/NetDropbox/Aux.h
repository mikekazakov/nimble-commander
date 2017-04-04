#pragma once

#ifdef RAPIDJSON_RAPIDJSON_H_
    #error include this file before rapidjson headers!
#endif

#define RAPIDJSON_48BITPOINTER_OPTIMIZATION   1
#define RAPIDJSON_SSE2 1
#define RAPIDJSON_HAS_STDSTRING 1

#include <rapidjson/rapidjson.h>
#include <rapidjson/document.h>
#include <rapidjson/error/en.h>
#include <rapidjson/memorystream.h>
#include <rapidjson/stringbuffer.h>

@class NSData;
@class NSURLSession;
@class NSURLRequest;
@class NSURLResponse;
@class NSError;

namespace VFSNetDropbox
{


    
    NSData *SendSynchonousRequest(NSURLSession *_session,
                                  NSURLRequest *_request,
                                  __autoreleasing NSURLResponse **_response_ptr,
                                  __autoreleasing NSError **_error_ptr);
    
    // + variant with cancellation



    struct Metadata
    {
        string name = ""; // will be empty on errors
        bool is_directory = false;
        int64_t size = -1;
        int64_t chg_time = -1;
    };
    Metadata ParseMetadata( const rapidjson::Value &_value );
    vector<Metadata> ExtractMetadataEntries( const rapidjson::Value &_value );
    
//    vector<Metadata> ListFolder(const string& _token,
//                                const string &_folder,
//                                const function<bool()> _cancellation );
//    

    const char *GetString( const rapidjson::Value &_doc, const char *_key );
    optional<long> GetLong( const rapidjson::Value &_doc, const char *_key );
    
    string EscapeString(const string &_original);
    string EscapeStringForJSONInHTTPHeader(const string &_original);
    
    
    bool IsNormalJSONResponse( NSURLResponse *_response );
    
    void WarnAboutUsingInMainThread();
    
};

