// Copyright (C) 2017-2021 Michael Kazakov. Subject to GNU General Public License version 3.
#pragma once

#include <rapidjson/rapidjson.h>
#include <rapidjson/document.h>
#include <rapidjson/error/en.h>
#include <rapidjson/memorystream.h>
#include <rapidjson/stringbuffer.h>
#include <VFS/VFSDeclarations.h>
#include <optional>
#include <sys/stat.h>

@class NSData;
@class NSURL;
@class NSURLSession;
@class NSURLRequest;
@class NSURLResponse;
@class NSMutableURLRequest;
@class NSError;

namespace nc::vfs::dropbox {

struct api {
    static NSURL *const GetCurrentAccount;
    static NSURL *const GetSpaceUsage;
    static NSURL *const GetMetadata;
    static NSURL *const ListFolder;
    static NSURL *const ListFolderContinue;
    static NSURL *const Delete;
    static NSURL *const CreateFolder;
    static NSURL *const Move;
    static NSURL *const Download;
    static NSURL *const Upload;
    static NSURL *const UploadSessionStart;
    static NSURL *const UploadSessionAppend;
    static NSURL *const UploadSessionFinish;
    static NSURL *const OAuth2Token;
    static NSURL *const OAuth2Authorize;
};

constexpr uint16_t DirectoryAccessMode = S_IRUSR | S_IWUSR | S_IFDIR | S_IXUSR;
constexpr uint16_t RegularFileAccessMode = S_IRUSR | S_IWUSR | S_IFREG;

void InsertHTTPBodyPathspec(NSMutableURLRequest *_request, std::string_view _path);
void InsertHTTPBodyCursor(NSMutableURLRequest *_request, const std::string &_cursor);
void InsertHTTPHeaderPathspec(NSMutableURLRequest *_request, const std::string &_path);

int ExtractVFSErrorFromJSON(NSData *_response_data);
int VFSErrorFromErrorAndReponseAndData(NSError *_error, NSURLResponse *_response, NSData *_data);

// returns VFSError and NSData, if VFSError is Ok
std::pair<int, NSData *> SendSynchronousRequest(NSURLSession *_session,
                                                NSURLRequest *_request,
                                                const VFSCancelChecker &_cancel_checker = nullptr);

struct Metadata {
    std::string name = ""; // will be empty on errors
    bool is_directory = false;
    int64_t size = -1;
    int64_t chg_time = -1;
};
Metadata ParseMetadata(const rapidjson::Value &_value);
std::vector<Metadata> ExtractMetadataEntries(const rapidjson::Value &_value);

struct AccountInfo {
    std::string accountid;
    std::string email;
    /* others later */
};
AccountInfo ParseAccountInfo(const rapidjson::Value &_value);

// returns an access token if the response was successfully parsed
std::optional<std::string> ParseRefreshTokenReponse(const rapidjson::Value &_value);

const char *GetString(const rapidjson::Value &_doc, const char *_key);
std::optional<long> GetLong(const rapidjson::Value &_doc, const char *_key);

std::string EscapeString(std::string_view _original);
std::string EscapeStringForJSONInHTTPHeader(const std::string &_original);

std::optional<rapidjson::Document> ParseJSON(NSData *_data);

bool IsNormalJSONResponse(NSURLResponse *_response);

}; // namespace nc::vfs::dropbox
