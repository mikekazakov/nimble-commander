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




};

