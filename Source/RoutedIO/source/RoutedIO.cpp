// Copyright (C) 2014-2023 Michael Kazakov. Subject to GNU General Public License version 3.
#include <ServiceManagement/ServiceManagement.h>
#include <Security/Security.h>
#include <Base/CommonPaths.h>
#include <Base/CFString.h>
#include <Base/CFPtr.h>
#include <Utility/SystemInformation.h>
#include <RoutedIO/RoutedIO.h>
#include <RoutedIO/Log.h>
#include <optional>
#include <vector>
#include <iostream>
#include "RoutedIOInterfaces.h"
#include "Internal.h"

namespace nc::routedio {

static PosixIOInterface &IODirectCreateProxy();
static PosixIOInterface &IOWrappedCreateProxy();

PosixIOInterface &RoutedIO::Direct = IODirectCreateProxy();
PosixIOInterface &RoutedIO::Default = IOWrappedCreateProxy();

static const char *g_HelperLabel = "info.filesmanager.Files.PrivilegedIOHelperV2";
static CFStringRef g_HelperLabelCF = base::CFStringCreateWithUTF8StringNoCopy(g_HelperLabel);

static const char *AuthRCToString(OSStatus _rc) noexcept;

static PosixIOInterface &IODirectCreateProxy()
{
    [[clang::no_destroy]] static PosixIOInterfaceNative direct;
    return direct;
}

static PosixIOInterface &IOWrappedCreateProxy()
{
    static PosixIOInterface *interface = []() -> PosixIOInterface * {
        return !nc::utility::IsThisProcessSandboxed() ? new PosixIOInterfaceRouted(RoutedIO::Instance())
                                                      : new PosixIOInterfaceNative();
    }();
    return *interface;
}

static std::optional<std::vector<std::uint8_t>> ReadFile(const char *_path)
{
    const int fd = open(_path, O_RDONLY);
    if( fd < 0 )
        return std::nullopt;

    const long size = lseek(fd, 0, SEEK_END);
    lseek(fd, 0, SEEK_SET);

    auto buf = std::vector<std::uint8_t>(size);

    uint8_t *buftmp = buf.data();
    uint64_t szleft = size;
    while( szleft ) {
        const ssize_t r = read(fd, buftmp, szleft);
        if( r < 0 ) {
            close(fd);
            return std::nullopt;
        }
        szleft -= r;
        buftmp += r;
    }

    close(fd);
    return std::move(buf);
}

static const char *InstalledPath()
{
    using namespace std::string_literals;
    [[clang::no_destroy]] static const std::string s = "/Library/PrivilegedHelperTools/"s + g_HelperLabel;
    return s.c_str();
}

static const char *BundledPath()
{
    [[clang::no_destroy]] static const std::string s =
        nc::base::CommonPaths::AppBundle() + "Contents/Library/LaunchServices/" + g_HelperLabel;
    return s.c_str();
}

RoutedIO::RoutedIO() : m_Sandboxed(nc::utility::IsThisProcessSandboxed())
{
}

RoutedIO &RoutedIO::Instance()
{
    [[clang::no_destroy]] static RoutedIO inst;
    return inst;
}

bool RoutedIO::IsHelperInstalled()
{
    return access(InstalledPath(), R_OK) == 0;
}

bool RoutedIO::IsHelperCurrent()
{
    auto inst = ReadFile(InstalledPath());
    auto bund = ReadFile(BundledPath());

    if( !inst || !bund )
        return false;

    if( inst->size() != bund->size() )
        return false;

    return memcmp(inst->data(), bund->data(), inst->size()) == 0;
}

bool RoutedIO::TurnOn()
{
    Log::Info("RoutedIO::TurnOn() called");

    if( m_Sandboxed ) {
        Log::Error("RoutedIO::TurnOn() was called in the sandboxed process.");
        return false;
    }

    if( m_Enabled )
        return true;

    if( !IsHelperInstalled() ) {
        Log::Info("The privileged helper is not installed.");
        if( !AskToInstallHelper() ) {
            Log::Error("Failed to install the privileged helper.");
            return false;
        }
    }

    if( !AuthenticateAsAdmin() ) {
        Log::Error("Failed to authenticate as admin, cannot turn RoutedIO on");
        return false;
    }

    if( IsHelperCurrent() ) {
        Log::Info("The installed privileged helper is the same as the bundled one.");
    }
    else {
        Log::Warn("Detected an outdated privileged helper.");
        // we have another version of a helper app
        if( Connect() && IsHelperAlive() ) {
            // ask helper it remove itself and then to exit gracefully
            xpc_connection_t connection = m_Connection;

            xpc_object_t message = xpc_dictionary_create(nullptr, nullptr, 0);
            xpc_dictionary_set_string(message, "operation", "uninstall");
            xpc_object_t reply = xpc_connection_send_message_with_reply_sync(connection, message);
            xpc_release(message);
            xpc_release(reply);

            message = xpc_dictionary_create(nullptr, nullptr, 0);
            xpc_dictionary_set_string(message, "operation", "exit");
            xpc_connection_send_message_with_reply(connection,
                                                   message,
                                                   dispatch_get_main_queue(),
                                                   ^([[maybe_unused]] xpc_object_t _event){
                                                   });
            xpc_release(message);

            xpc_release(m_Connection);
            m_Connection = nullptr;

            if( !AskToInstallHelper() ) {
                Log::Error("Failed to install the privileged helper.");
                return false;
            }
        }
        else {
            // the helper is not current + we can't ask it to remove itself. protocol/signing probs?
            // anyway, can't go this way, no turning routing on
            Log::Error("Failed to communicate with an outdated helper.");
            return false;
        }
    }

    if( Connect() )
        m_Enabled = true;

    Log::Info("RoutedIO enabled={}", m_Enabled.load());

    return m_Enabled;
}

void RoutedIO::TurnOff()
{
    Log::Info("RoutedIO::Turnoff() called");

    if( m_Connection ) {
        xpc_connection_cancel(m_Connection);
        xpc_release(m_Connection);
        m_Connection = nullptr;
    }
    m_Enabled = false;
    m_AuthenticatedAsAdmin = false;

    Log::Info("RoutedIO enabled={}", m_Enabled.load());
}

bool RoutedIO::SayImAuthenticated(xpc_connection_t _connection) noexcept
{
    xpc_object_t message = xpc_dictionary_create(nullptr, nullptr, 0);
    xpc_dictionary_set_bool(message, "auth", m_AuthenticatedAsAdmin);

    xpc_object_t reply = xpc_connection_send_message_with_reply_sync(_connection, message);
    xpc_release(message);

    bool result = false;
    if( xpc_get_type(reply) != XPC_TYPE_ERROR )
        if( xpc_dictionary_get_bool(reply, "ok") )
            result = true;

    xpc_release(reply);
    return result;
}

bool RoutedIO::AskToInstallHelper()
{
    if( m_Sandboxed ) {
        Log::Error("RoutedIO::AskToInstallHelper() was called in a sandboxed process");
        return false;
    }

    AuthorizationItem auth_item = {kSMRightBlessPrivilegedHelper, 0, nullptr, 0};
    const AuthorizationRights auth_rights = {1, &auth_item};
    const AuthorizationFlags flags =
        kAuthorizationFlagInteractionAllowed | kAuthorizationFlagPreAuthorize | kAuthorizationFlagExtendRights;
    AuthorizationRef auth_ref = nullptr;

    // Provide a text prompt for the request
    std::string prompt = MessageInstallHelperApp();
    AuthorizationItem auth_env_item = {kAuthorizationEnvironmentPrompt, prompt.size(), prompt.data(), 0};
    const AuthorizationEnvironment auth_env = {1, &auth_env_item};

    // Obtain the right to install privileged helper tools (kSMRightBlessPrivilegedHelper).
    const OSStatus status = AuthorizationCreate(&auth_rights, &auth_env, flags, &auth_ref);
    if( status == errAuthorizationSuccess ) {
        Log::Info("Successfully authenticated for SMRightBless");
    }
    else {
        Log::Error("RoutedIO::AskToInstallHelper() failed to execute AuthorizationCreate() with "
                   "the error: {}.",
                   AuthRCToString(status));
        return false;
    }

    // We implicitly assume that admin auth was provided
    m_AuthenticatedAsAdmin = true;
    CFErrorRef error;

    const bool result = SMJobBless(kSMDomainSystemLaunchd, g_HelperLabelCF, auth_ref, &error);
    if( result ) {
        Log::Info("Successfully installed a privileged helper");
    }
    else if( error != nullptr ) {
        if( auto desc = base::CFPtr<CFStringRef>::adopt(CFErrorCopyDescription(error)) )
            Log::Error("RoutedIO::AskToInstallHelper() SMJobBless failed with error: {}. ",
                       base::CFStringGetUTF8StdString(desc.get()));
        if( auto desc = base::CFPtr<CFStringRef>::adopt(CFErrorCopyFailureReason(error)) )
            Log::Error("RoutedIO::AskToInstallHelper() SMJobBless failed with failure reason: {}. ",
                       base::CFStringGetUTF8StdString(desc.get()));
        if( auto desc = base::CFPtr<CFStringRef>::adopt(CFErrorCopyRecoverySuggestion(error)) )
            Log::Error("RoutedIO::AskToInstallHelper() SMJobBless failed with recovery suggestion: {}. ",
                       base::CFStringGetUTF8StdString(desc.get()));
        CFRelease(error);
    }

    AuthorizationFree(auth_ref, kAuthorizationFlagDefaults);

    return result;
}

bool RoutedIO::AuthenticateAsAdmin()
{
    Log::Debug("RoutedIO::AuthenticateAsAdmin() called");

    if( m_Sandboxed ) {
        Log::Error("RoutedIO::AuthenticateAsAdmin() was called in a sandboxed process");
        return false;
    }

    if( m_AuthenticatedAsAdmin ) {
        Log::Debug("Already authenticated");
        return true;
    }

    // Request to auth as admin
    AuthorizationItem auth_rights_item = {kAuthorizationRuleAuthenticateAsAdmin, 0, nullptr, 0};
    const AuthorizationRights auth_rights = {1, &auth_rights_item};

    // Provide a text prompt for the request
    std::string prompt = MessageAuthAsAdmin();
    AuthorizationItem auth_env_item = {kAuthorizationEnvironmentPrompt, prompt.size(), prompt.data(), 0};
    const AuthorizationEnvironment auth_env = {1, &auth_env_item};

    // What to auth now
    const AuthorizationFlags flags =
        kAuthorizationFlagInteractionAllowed | kAuthorizationFlagPreAuthorize | kAuthorizationFlagExtendRights;

    const OSStatus status = AuthorizationCreate(&auth_rights, &auth_env, flags, nullptr);

    if( status == errAuthorizationSuccess ) {
        Log::Info("Successfully authenticated as administrator");
        m_AuthenticatedAsAdmin = true;
    }
    else {
        Log::Error("RoutedIO::AuthenticateAsAdmin() failed to execute AuthorizationCreate() with "
                   "the error: {}",
                   AuthRCToString(status));
    }

    return m_AuthenticatedAsAdmin;
}

bool RoutedIO::Connect()
{
    if( m_Connection )
        return true;

    if( !m_AuthenticatedAsAdmin ) {
        Log::Error("RoutedIO::Connect() was called without being authenticated as admin");
        return false;
    }

    xpc_connection_t connection =
        xpc_connection_create_mach_service(g_HelperLabel, nullptr, XPC_CONNECTION_MACH_SERVICE_PRIVILEGED);
    if( !connection ) {
        Log::Error("RoutedIO::Connect() failed to call xpc_connection_create_mach_service()");
        return false;
    }

    xpc_connection_set_event_handler(connection, ^(xpc_object_t event) {
      xpc_type_t type = xpc_get_type(event);
      if( type == XPC_TYPE_ERROR ) {
          if( event == XPC_ERROR_CONNECTION_INVALID ) {
              m_Connection = nullptr;
          }
      }
    });

    xpc_connection_resume(connection);

    if( !SayImAuthenticated(connection) ) {
        Log::Error("RoutedIO::Connect() failed to call SayImAuthenticated()");
        xpc_connection_cancel(connection);
        return false;
    }

    m_Connection = connection;
    return true;
}

bool RoutedIO::ConnectionAvailable()
{
    return m_Connection != nullptr;
}

xpc_connection_t RoutedIO::Connection()
{
    if( ConnectionAvailable() )
        return m_Connection;
    if( Connect() )
        return m_Connection;
    return nullptr;
}

bool RoutedIO::IsHelperAlive()
{
    xpc_connection_t connection = Connection();
    if( !connection )
        return false;

    xpc_object_t message = xpc_dictionary_create(nullptr, nullptr, 0);
    xpc_dictionary_set_string(message, "operation", "heartbeat");

    xpc_object_t reply = xpc_connection_send_message_with_reply_sync(connection, message);
    xpc_release(message);

    bool result = false;
    if( xpc_get_type(reply) != XPC_TYPE_ERROR )
        if( xpc_dictionary_get_bool(reply, "ok") )
            result = true;

    xpc_release(reply);
    return result;
}

PosixIOInterface &RoutedIO::InterfaceForAccess(const char *_path, int _mode) noexcept
{
    auto &instance = Instance();
    if( instance.m_Sandboxed )
        return Direct;

    if( !instance.m_Enabled )
        return Direct;

    return access(_path, _mode) == 0 ? RoutedIO::Direct : RoutedIO::Default;
}

bool RoutedIO::Enabled() const noexcept
{
    return m_Enabled;
}

void RoutedIO::InstallViaRootCLI()
{
    if( geteuid() != 0 ) {
        std::cerr << "this command must be executed with root rights." << '\n';
        return;
    }

    if( utility::IsThisProcessSandboxed() ) {
        std::cerr << "must be not a sandboxed process." << '\n';
        return;
    }

    AuthorizationItem auth_item = {kSMRightBlessPrivilegedHelper, 0, nullptr, 0};
    const AuthorizationRights auth_rights = {1, &auth_item};
    const AuthorizationFlags flags = kAuthorizationFlagPreAuthorize | kAuthorizationFlagExtendRights;
    AuthorizationRef auth_ref = nullptr;

    // Obtain the right to install privileged helper tools (kSMRightBlessPrivilegedHelper).
    const OSStatus status = AuthorizationCreate(&auth_rights, nullptr, flags, &auth_ref);
    if( status != errAuthorizationSuccess ) {
        std::cerr << "AuthorizationCreate() failed with the error: " << AuthRCToString(status) << "." << '\n';
        return;
    }

    CFErrorRef error = nullptr;
    const bool result = SMJobBless(kSMDomainSystemLaunchd, g_HelperLabelCF, auth_ref, &error);
    if( !result && error != nullptr ) {
        if( auto desc = base::CFPtr<CFStringRef>::adopt(CFErrorCopyDescription(error)) )
            std::cerr << base::CFStringGetUTF8StdString(desc.get()) << '\n';
        if( auto desc = base::CFPtr<CFStringRef>::adopt(CFErrorCopyFailureReason(error)) )
            std::cerr << base::CFStringGetUTF8StdString(desc.get()) << '\n';
        if( auto desc = base::CFPtr<CFStringRef>::adopt(CFErrorCopyRecoverySuggestion(error)) )
            std::cerr << base::CFStringGetUTF8StdString(desc.get()) << '\n';
        CFRelease(error);
    }

    AuthorizationFree(auth_ref, kAuthorizationFlagDefaults);
}
void RoutedIO::UninstallViaRootCLI()
{
    using namespace std::string_literals;

    if( geteuid() != 0 ) {
        std::cerr << "this command must be executed with root rights." << '\n';
        return;
    }

    if( utility::IsThisProcessSandboxed() ) {
        std::cerr << "must be not a sandboxed process." << '\n';
        return;
    }

    system(("launchctl unload /Library/LaunchDaemons/"s + g_HelperLabel + ".plist"s).c_str());
    system(("rm -v /Library/LaunchDaemons/"s + g_HelperLabel + ".plist"s).c_str());
    system(("rm -v /Library/PrivilegedHelperTools/"s + g_HelperLabel).c_str());
}

PosixIOInterface::~PosixIOInterface() = default;

static const char *AuthRCToString(OSStatus _rc) noexcept
{
    switch( _rc ) {
        case errAuthorizationSuccess:
            return "errAuthorizationSuccess";
        case errAuthorizationInvalidSet:
            return "errAuthorizationInvalidSet";
        case errAuthorizationInvalidRef:
            return "errAuthorizationInvalidRef";
        case errAuthorizationInvalidTag:
            return "errAuthorizationInvalidTag";
        case errAuthorizationInvalidPointer:
            return "errAuthorizationInvalidPointer";
        case errAuthorizationDenied:
            return "errAuthorizationDenied";
        case errAuthorizationCanceled:
            return "errAuthorizationCanceled";
        case errAuthorizationInteractionNotAllowed:
            return "errAuthorizationInteractionNotAllowed";
        case errAuthorizationInternal:
            return "errAuthorizationInternal";
        case errAuthorizationExternalizeNotAllowed:
            return "errAuthorizationExternalizeNotAllowed";
        case errAuthorizationInternalizeNotAllowed:
            return "errAuthorizationInternalizeNotAllowed";
        case errAuthorizationInvalidFlags:
            return "errAuthorizationInvalidFlags";
        case errAuthorizationToolExecuteFailure:
            return "errAuthorizationToolExecuteFailure";
        case errAuthorizationToolEnvironmentError:
            return "errAuthorizationToolEnvironmentError";
        case errAuthorizationBadAddress:
            return "errAuthorizationBadAddress";
        default:
            return "Unknown OSStatus";
    }
}
} // namespace nc::routedio
