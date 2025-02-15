// Copyright (C) 2021-2025 Michael Kazakov. Subject to GNU General Public License version 3.
#include "Tests.h"
#include "TestEnv.h"
#include <VFS/NetDropbox.h>
#include <VFS/../../source/NetDropbox/File.h>
#include <Base/dispatch_cpp.h>
#include <set>
#include <queue>
#include <optional>

using namespace nc;
using namespace nc::vfs;

#define PREFIX "VFSDropbox "

@class NCVFSDropBoxMockSessionTask;
@class NCVFSDropboxMockURLSession;

namespace {

struct Reaction {
    // responses
    NSData *data = nil;
    NSURLResponse *response = nil;
    NSError *error = nil;

    // expectations
    std::optional<std::string> exp_URL;
    std::optional<std::string> exp_HTTPMethod;
    std::optional<NSDictionary<NSString *, NSString *> *> exp_HTTPHeaderFields;
    std::optional<std::string> exp_HTTPBody;
};

class URLSessionMockFactory : public dropbox::URLSessionCreator
{
public:
    NSURLSession *CreateSession(NSURLSessionConfiguration *configuration) override;
    NSURLSession *CreateSession(NSURLSessionConfiguration *_configuration,
                                id<NSURLSessionDelegate> _delegate,
                                NSOperationQueue *_queue) override;

    void AddReaction(const Reaction &_reaction);
    Reaction &AddReaction();
    const Reaction *NextReaction();
    void PopReaction();

private:
    std::queue<Reaction> m_Reactions;
};

} // namespace

@interface NCVFSDropboxMockURLSession : NSURLSession
- (instancetype)initWithFactory:(URLSessionMockFactory &)_factory
                       delegate:(nullable id<NSURLSessionDelegate>)_delegate
                  delegateQueue:(nullable NSOperationQueue *)_queue;
@property(readonly, nonatomic, nullable) id<NSURLSessionDelegate> delegate;
@property(readonly, nonatomic, nullable) NSOperationQueue *delegateQueue;
@property(readonly, nonatomic) URLSessionMockFactory &factory;
@end

@interface NCVFSDropBoxMockSessionTask : NSURLSessionDataTask
- (instancetype)initWithSession:(NCVFSDropboxMockURLSession *)_session;
@property(readwrite, nonatomic, nullable) void (^completionHandler)
    (NSData *_Nullable data, NSURLResponse *_Nullable response, NSError *_Nullable error);
@property(readwrite, nonatomic) NSURLRequest *request;
@end

NSURLSession *URLSessionMockFactory::CreateSession(NSURLSessionConfiguration *configuration)
{
    return CreateSession(configuration, nil, nil);
}

NSURLSession *URLSessionMockFactory::CreateSession([[maybe_unused]] NSURLSessionConfiguration *_configuration,
                                                   id<NSURLSessionDelegate> _delegate,
                                                   NSOperationQueue *_queue)
{
    return [[NCVFSDropboxMockURLSession alloc] initWithFactory:*this delegate:_delegate delegateQueue:_queue];
}

void URLSessionMockFactory::AddReaction(const Reaction &_reaction)
{
    m_Reactions.emplace(_reaction);
}

Reaction &URLSessionMockFactory::AddReaction()
{
    m_Reactions.emplace();
    return m_Reactions.back();
}

const Reaction *URLSessionMockFactory::NextReaction()
{
    return m_Reactions.empty() ? nullptr : &m_Reactions.front();
}

void URLSessionMockFactory::PopReaction()
{
    if( !m_Reactions.empty() ) {
        m_Reactions.pop();
        return;
    }
}

@implementation NCVFSDropboxMockURLSession {
    id<NSURLSessionDelegate> m_Delegate;
    NSOperationQueue *m_DelegateQueue;
    URLSessionMockFactory *m_Factory;
}

@synthesize delegate = m_Delegate;
@synthesize delegateQueue = m_DelegateQueue;

- (instancetype)initWithFactory:(URLSessionMockFactory &)_factory
                       delegate:(nullable id<NSURLSessionDelegate>)_delegate
                  delegateQueue:(nullable NSOperationQueue *)_queue
{
    if( self ) { // don't call [super init] - NSURLSession stuff will be surprised
        m_Factory = &_factory;
        m_Delegate = _delegate;
        m_DelegateQueue = _queue;
    }
    return self;
}

- (NSURLSessionDataTask *)dataTaskWithRequest:(NSURLRequest *)_request
{
    NCVFSDropBoxMockSessionTask *task = [[NCVFSDropBoxMockSessionTask alloc] initWithSession:self];
    task.request = _request;
    return task;
}

- (NSURLSessionDataTask *)dataTaskWithRequest:(NSURLRequest *)_request
                            completionHandler:(void (^)(NSData *_Nullable data,
                                                        NSURLResponse *_Nullable response,
                                                        NSError *_Nullable error))_completionHandler
{
    NCVFSDropBoxMockSessionTask *task = [[NCVFSDropBoxMockSessionTask alloc] initWithSession:self];
    task.completionHandler = _completionHandler;
    task.request = _request;
    return task;
}

- (URLSessionMockFactory &)factory
{
    assert(m_Factory != nullptr);
    return *m_Factory;
}

@end

@implementation NCVFSDropBoxMockSessionTask {
    __weak NCVFSDropboxMockURLSession *m_Session;
}
@synthesize completionHandler;
@synthesize request;

- (instancetype)initWithSession:(NCVFSDropboxMockURLSession *)_session
{
    if( self ) { // don't call [super init] - NSURLSession stuff will be surprised
        assert(_session);
        m_Session = _session;
    }
    return self;
}

- (void)cancel
{
    // TODO: implement... something
}

- (void)resume
{
    // Find a canned reaction for this task
    NCVFSDropboxMockURLSession *session = m_Session;
    if( !session )
        return;
    URLSessionMockFactory &factory = session.factory;
    REQUIRE(factory.NextReaction() != nullptr);
    const Reaction react = *factory.NextReaction();
    factory.PopReaction();

    // Check the expectactions
    if( react.exp_URL ) {
        CHECK(*react.exp_URL == self.request.URL.absoluteString.UTF8String);
    }
    if( react.exp_HTTPMethod ) {
        CHECK(*react.exp_HTTPMethod == self.request.HTTPMethod.UTF8String);
    }
    if( react.exp_HTTPHeaderFields ) {
        CHECK([*react.exp_HTTPHeaderFields isEqualToDictionary:self.request.allHTTPHeaderFields]);
    }
    if( react.exp_HTTPBody ) {
        CHECK(*react.exp_HTTPBody ==
              [[NSString alloc] initWithData:self.request.HTTPBody encoding:NSUTF8StringEncoding].UTF8String);
    }

    // Send the reponse via completion handler
    if( self.completionHandler )
        dispatch_to_background(
            [react, handler = self.completionHandler] { handler(react.data, react.response, react.error); });
}

@end

[[maybe_unused]] static NSData *D(NSString *_string)
{
    return [_string dataUsingEncoding:NSUTF8StringEncoding];
}

static NSData *D(const char *_string)
{
    return [[NSString stringWithUTF8String:_string] dataUsingEncoding:NSUTF8StringEncoding];
}

static NSHTTPURLResponse *R200()
{
    return [[NSHTTPURLResponse alloc] initWithURL:[NSURL URLWithString:@"https://doesnt-matter"]
                                       statusCode:200
                                      HTTPVersion:nil
                                     headerFields:nil];
}

static NSHTTPURLResponse *R401()
{
    return [[NSHTTPURLResponse alloc] initWithURL:[NSURL URLWithString:@"https://doesnt-matter"]
                                       statusCode:401
                                      HTTPVersion:nil
                                     headerFields:nil];
}

static const auto g_MockClientID = "AAAAAAAAAAAAAAA";
static const auto g_MockClientSecret = "BBBBBBBBBBBBBBB";
static DropboxHost::Params MakeDefaultParams()
{
    DropboxHost::Params params;
    params.client_id = g_MockClientID;
    params.client_secret = g_MockClientSecret;
    return params;
}

TEST_CASE(PREFIX "Initialization with an old token")
{
    URLSessionMockFactory factory;

    Reaction &r = factory.AddReaction(); // get an account info
    r.response = R200();
    r.data = D(R"({"account_id":"dbid:12345", "email":"foobar@example.com"})");
    r.exp_URL = "https://api.dropboxapi.com/2/users/get_current_account";
    r.exp_HTTPMethod = "POST";
    r.exp_HTTPHeaderFields = @{@"Authorization": @"Bearer 1234567890"};

    DropboxHost::Params params = MakeDefaultParams();
    params.account = "foobar@example.com";
    params.access_token = "1234567890";
    params.session_creator = &factory;
    std::make_shared<DropboxHost>(params);
}

TEST_CASE(PREFIX "Initialization with a refresh token")
{
    URLSessionMockFactory factory;

    Reaction &r1 = factory.AddReaction(); // r1 - convert a refresh token into a short-lived token
    r1.response = R200();
    r1.data = D(R"({"token_type":"bearer", "access_token":"sl.qwertyuiop"})");
    r1.exp_URL = "https://api.dropbox.com/oauth2/token";
    r1.exp_HTTPMethod = "POST";
    r1.exp_HTTPBody = "grant_type=refresh_token&refresh_token=5678901234&client_id=AAAAAAAAAAAAAAA&"
                      "client_secret=BBBBBBBBBBBBBBB";

    Reaction &r2 = factory.AddReaction(); // r2 - get an account info
    r2.response = R200();
    r2.data = D(R"({"account_id": "dbid:12345", "email":"foobar@example.com"})");
    r2.exp_URL = "https://api.dropboxapi.com/2/users/get_current_account";
    r2.exp_HTTPMethod = "POST";
    r2.exp_HTTPHeaderFields = @{@"Authorization": @"Bearer sl.qwertyuiop"};

    DropboxHost::Params params = MakeDefaultParams();
    params.account = "foobar@example.com";
    params.access_token = "<refresh-token>5678901234";
    params.session_creator = &factory;
    std::make_shared<DropboxHost>(params);
}

TEST_CASE(PREFIX "Operation with a refresh token")
{
    URLSessionMockFactory factory;

    Reaction &r1 = factory.AddReaction(); // r1 - convert a refresh token into a short-lived token
    r1.response = R200();
    r1.data = D(R"({"token_type":"bearer", "access_token":"sl.qwertyuiop"})");
    r1.exp_URL = "https://api.dropbox.com/oauth2/token";
    r1.exp_HTTPMethod = "POST";
    r1.exp_HTTPBody = "grant_type=refresh_token&refresh_token=5678901234&client_id=AAAAAAAAAAAAAAA&"
                      "client_secret=BBBBBBBBBBBBBBB";

    Reaction &r2 = factory.AddReaction(); // r2 - get an account info
    r2.response = R200();
    r2.data = D(R"({"account_id": "dbid:12345", "email":"foobar@example.com"})");
    r2.exp_URL = "https://api.dropboxapi.com/2/users/get_current_account";
    r2.exp_HTTPMethod = "POST";
    r2.exp_HTTPHeaderFields = @{@"Authorization": @"Bearer sl.qwertyuiop"};

    SECTION("No need for reauth")
    {
        Reaction &r3 = factory.AddReaction(); // r3 - get fs info
        r3.response = R200();
        r3.data = D(R"({"used":1000, "allocation":{"allocated":10000}})");
        r3.exp_URL = "https://api.dropboxapi.com/2/users/get_space_usage";
        r3.exp_HTTPMethod = "POST";
        r3.exp_HTTPHeaderFields = @{@"Authorization": @"Bearer sl.qwertyuiop"};
    }
    SECTION("Must reauth")
    {
        Reaction &r3 = factory.AddReaction(); // r3 - fails with 401
        r3.response = R401();
        r3.exp_URL = "https://api.dropboxapi.com/2/users/get_space_usage";
        r3.exp_HTTPMethod = "POST";
        r3.exp_HTTPHeaderFields = @{@"Authorization": @"Bearer sl.qwertyuiop"};

        Reaction &r4 = factory.AddReaction(); // r4 - reauth
        r4.response = R200();
        r4.data = D(R"({"token_type":"bearer", "access_token":"sl.asdfghjkl"})");
        r4.exp_URL = "https://api.dropbox.com/oauth2/token";
        r4.exp_HTTPMethod = "POST";
        r4.exp_HTTPBody = "grant_type=refresh_token&refresh_token=5678901234&client_id=AAAAAAAAAAAAAAA&"
                          "client_secret=BBBBBBBBBBBBBBB";

        Reaction &r5 = factory.AddReaction(); // r5 - get fs info
        r5.response = R200();
        r5.data = D(R"({"used":1000, "allocation":{"allocated":10000}})");
        r5.exp_URL = "https://api.dropboxapi.com/2/users/get_space_usage";
        r5.exp_HTTPMethod = "POST";
        r5.exp_HTTPHeaderFields = @{@"Authorization": @"Bearer sl.asdfghjkl"};
    }

    DropboxHost::Params params = MakeDefaultParams();
    params.account = "foobar@example.com";
    params.access_token = "<refresh-token>5678901234";
    params.session_creator = &factory;
    auto host = std::make_shared<DropboxHost>(params);

    const VFSStatFS statfs = host->StatFS("/").value();
    CHECK(statfs.total_bytes == 10000);
    CHECK(statfs.avail_bytes == 9000);
    CHECK(statfs.free_bytes == 9000);
    CHECK(statfs.volume_name == "foobar@example.com");
}

TEST_CASE(PREFIX "Failed re-auth")
{
    URLSessionMockFactory factory;

    Reaction &r1 = factory.AddReaction(); // r1 - convert a refresh token into a short-lived token
    r1.response = R200();
    r1.data = D(R"({"token_type":"bearer", "access_token":"sl.qwertyuiop"})");
    r1.exp_URL = "https://api.dropbox.com/oauth2/token";
    r1.exp_HTTPMethod = "POST";
    r1.exp_HTTPBody = "grant_type=refresh_token&refresh_token=5678901234&client_id=AAAAAAAAAAAAAAA&"
                      "client_secret=BBBBBBBBBBBBBBB";

    Reaction &r2 = factory.AddReaction(); // r2 - get an account info
    r2.response = R200();
    r2.data = D(R"({"account_id": "dbid:12345", "email":"foobar@example.com"})");
    r2.exp_URL = "https://api.dropboxapi.com/2/users/get_current_account";
    r2.exp_HTTPMethod = "POST";
    r2.exp_HTTPHeaderFields = @{@"Authorization": @"Bearer sl.qwertyuiop"};

    Reaction &r3 = factory.AddReaction(); // r3 - fails with 401
    r3.response = R401();
    r3.exp_URL = "https://api.dropboxapi.com/2/users/get_space_usage";
    r3.exp_HTTPMethod = "POST";
    r3.exp_HTTPHeaderFields = @{@"Authorization": @"Bearer sl.qwertyuiop"};

    Reaction &r4 = factory.AddReaction(); // r4 - failed reauth
    r4.response = R401();
    r4.exp_URL = "https://api.dropbox.com/oauth2/token";
    r4.exp_HTTPMethod = "POST";
    r4.exp_HTTPBody = "grant_type=refresh_token&refresh_token=5678901234&client_id=AAAAAAAAAAAAAAA&"
                      "client_secret=BBBBBBBBBBBBBBB";

    DropboxHost::Params params = MakeDefaultParams();
    params.account = "foobar@example.com";
    params.access_token = "<refresh-token>5678901234";
    params.session_creator = &factory;
    auto host = std::make_shared<DropboxHost>(params);

    CHECK(host->StatFS("/").error() == Error{Error::POSIX, EAUTH});
}
