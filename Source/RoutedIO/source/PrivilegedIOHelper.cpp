// Copyright (C) 2014-2024 Michael Kazakov. Subject to GNU General Public License version 3.
#include "Trash.h"
#include <Security/Security.h>
#include <cerrno>
#include <cstdio>
#include <frozen/string.h>
#include <frozen/unordered_map.h>
#include <libproc.h>
#include <mach-o/dyld.h>
#include <sys/stat.h>
#include <syslog.h>
#include <xpc/xpc.h>
#include <Base/CFPtr.h>

// requires that identifier is right and binary is signed by me
static const char *g_SignatureRequirement =
    "identifier info.filesmanager.Files and "
    "certificate leaf[subject.CN] = \"Developer ID Application: Mikhail Kazakov (AC5SJT236H)\"";

static const char *g_ServiceName = "info.filesmanager.Files.PrivilegedIOHelperV2";

#define syslog_error(...) syslog(LOG_ERR, __VA_ARGS__)
#define syslog_warning(...) syslog(LOG_WARNING, __VA_ARGS__)
#ifdef DEBUG
#define syslog_notice(...) syslog(LOG_NOTICE, __VA_ARGS__)
#else
#define syslog_notice(...)
#endif

struct ConnectionContext {
    bool authenticated = false;
};

static void send_reply_error(xpc_object_t _from_event, int _error)
{
    xpc_connection_t remote = xpc_dictionary_get_remote_connection(_from_event);
    xpc_object_t reply = xpc_dictionary_create_reply(_from_event);
    xpc_dictionary_set_int64(reply, "error", _error);
    xpc_connection_send_message(remote, reply);
    xpc_release(reply);
}

static void send_reply_ok(xpc_object_t _from_event)
{
    xpc_connection_t remote = xpc_dictionary_get_remote_connection(_from_event);
    xpc_object_t reply = xpc_dictionary_create_reply(_from_event);
    xpc_dictionary_set_bool(reply, "ok", true);
    xpc_connection_send_message(remote, reply);
    xpc_release(reply);
}

static void send_reply_fd(xpc_object_t _from_event, int _fd)
{
    xpc_connection_t remote = xpc_dictionary_get_remote_connection(_from_event);
    xpc_object_t reply = xpc_dictionary_create_reply(_from_event);
    xpc_dictionary_set_fd(reply, "fd", _fd);
    xpc_connection_send_message(remote, reply);
    xpc_release(reply);
}

static bool HandleHeartbeat(xpc_object_t _event) noexcept
{
    syslog_notice("processing heartbeat request");
    send_reply_ok(_event);
    return true;
}

static bool HandleUninstall(xpc_object_t _event) noexcept
{
    char path[1024];
    proc_pidpath(getpid(), path, sizeof(path));
    if( unlink(path) == 0 ) {
        send_reply_ok(_event);
    }
    else {
        send_reply_error(_event, errno);
    }
    return true;
}

static bool HandleExit([[maybe_unused]] xpc_object_t _event) noexcept
{
    // no response here
    syslog_notice("goodbye, cruel world!");
    exit(0);
}

static bool HandleOpen(xpc_object_t _event) noexcept
{
    xpc_object_t xpc_path = xpc_dictionary_get_value(_event, "path");
    if( xpc_path == nullptr || xpc_get_type(xpc_path) != XPC_TYPE_STRING )
        return false;
    const char *path = xpc_string_get_string_ptr(xpc_path);

    xpc_object_t xpc_flags = xpc_dictionary_get_value(_event, "flags");
    if( xpc_flags == nullptr || xpc_get_type(xpc_flags) != XPC_TYPE_INT64 )
        return false;
    const int flags = static_cast<int>(xpc_int64_get_value(xpc_flags));

    xpc_object_t xpc_mode = xpc_dictionary_get_value(_event, "mode");
    if( xpc_mode == nullptr || xpc_get_type(xpc_mode) != XPC_TYPE_INT64 )
        return false;
    const int mode = static_cast<int>(xpc_int64_get_value(xpc_mode));

    const int fd = open(path, flags, mode);
    if( fd >= 0 ) {
        send_reply_fd(_event, fd);
        close(fd);
    }
    else {
        send_reply_error(_event, errno);
    }
    return true;
}

static bool HandleStat(xpc_object_t _event) noexcept
{
    xpc_object_t xpc_path = xpc_dictionary_get_value(_event, "path");
    if( xpc_path == nullptr || xpc_get_type(xpc_path) != XPC_TYPE_STRING )
        return false;

    const char *path = xpc_string_get_string_ptr(xpc_path);
    struct stat st;
    const int ret = stat(path, &st);
    if( ret == 0 ) {
        xpc_connection_t remote = xpc_dictionary_get_remote_connection(_event);
        xpc_object_t reply = xpc_dictionary_create_reply(_event);
        xpc_dictionary_set_data(reply, "st", &st, sizeof(st));
        xpc_connection_send_message(remote, reply);
        xpc_release(reply);
    }
    else {
        send_reply_error(_event, errno);
    }
    return true;
}

static bool HandleLStat(xpc_object_t _event) noexcept
{
    xpc_object_t xpc_path = xpc_dictionary_get_value(_event, "path");
    if( xpc_path == nullptr || xpc_get_type(xpc_path) != XPC_TYPE_STRING )
        return false;

    const char *path = xpc_string_get_string_ptr(xpc_path);
    struct stat st;
    const int ret = lstat(path, &st);
    if( ret == 0 ) {
        xpc_connection_t remote = xpc_dictionary_get_remote_connection(_event);
        xpc_object_t reply = xpc_dictionary_create_reply(_event);
        xpc_dictionary_set_data(reply, "st", &st, sizeof(st));
        xpc_connection_send_message(remote, reply);
        xpc_release(reply);
    }
    else {
        send_reply_error(_event, errno);
    }
    return true;
}

static bool HandleMkDir(xpc_object_t _event) noexcept
{
    xpc_object_t xpc_path = xpc_dictionary_get_value(_event, "path");
    if( xpc_path == nullptr || xpc_get_type(xpc_path) != XPC_TYPE_STRING )
        return false;
    const char *path = xpc_string_get_string_ptr(xpc_path);

    xpc_object_t xpc_mode = xpc_dictionary_get_value(_event, "mode");
    if( xpc_mode == nullptr || xpc_get_type(xpc_mode) != XPC_TYPE_INT64 )
        return false;
    const int mode = static_cast<int>(xpc_int64_get_value(xpc_mode));

    const int result = mkdir(path, static_cast<mode_t>(mode));
    if( result == 0 ) {
        send_reply_ok(_event);
    }
    else {
        send_reply_error(_event, errno);
    }
    return true;
}

static bool HandleChOwn(xpc_object_t _event) noexcept
{
    xpc_object_t xpc_path = xpc_dictionary_get_value(_event, "path");
    if( xpc_path == nullptr || xpc_get_type(xpc_path) != XPC_TYPE_STRING )
        return false;
    const char *path = xpc_string_get_string_ptr(xpc_path);

    xpc_object_t xpc_uid = xpc_dictionary_get_value(_event, "uid");
    if( xpc_uid == nullptr || xpc_get_type(xpc_uid) != XPC_TYPE_INT64 )
        return false;
    const uid_t uid = static_cast<uid_t>(xpc_int64_get_value(xpc_uid));

    xpc_object_t xpc_gid = xpc_dictionary_get_value(_event, "gid");
    if( xpc_gid == nullptr || xpc_get_type(xpc_gid) != XPC_TYPE_INT64 )
        return false;
    const gid_t gid = static_cast<gid_t>(xpc_int64_get_value(xpc_gid));

    const int result = chown(path, uid, gid);
    if( result == 0 ) {
        send_reply_ok(_event);
    }
    else {
        send_reply_error(_event, errno);
    }
    return true;
}

static bool HandleChFlags(xpc_object_t _event) noexcept
{
    xpc_object_t xpc_path = xpc_dictionary_get_value(_event, "path");
    if( xpc_path == nullptr || xpc_get_type(xpc_path) != XPC_TYPE_STRING )
        return false;
    const char *path = xpc_string_get_string_ptr(xpc_path);

    xpc_object_t xpc_flags = xpc_dictionary_get_value(_event, "flags");
    if( xpc_flags == nullptr || xpc_get_type(xpc_flags) != XPC_TYPE_INT64 )
        return false;
    const u_int flags = static_cast<u_int>(xpc_int64_get_value(xpc_flags));

    const int result = chflags(path, flags);
    if( result == 0 ) {
        send_reply_ok(_event);
    }
    else {
        send_reply_error(_event, errno);
    }
    return true;
}

static bool HandleLChFlags(xpc_object_t _event) noexcept
{
    xpc_object_t xpc_path = xpc_dictionary_get_value(_event, "path");
    if( xpc_path == nullptr || xpc_get_type(xpc_path) != XPC_TYPE_STRING )
        return false;
    const char *path = xpc_string_get_string_ptr(xpc_path);

    xpc_object_t xpc_flags = xpc_dictionary_get_value(_event, "flags");
    if( xpc_flags == nullptr || xpc_get_type(xpc_flags) != XPC_TYPE_INT64 )
        return false;
    const u_int flags = static_cast<u_int>(xpc_int64_get_value(xpc_flags));

    const int result = lchflags(path, flags);
    if( result == 0 ) {
        send_reply_ok(_event);
    }
    else {
        send_reply_error(_event, errno);
    }
    return true;
}

static bool HandleChMod(xpc_object_t _event) noexcept
{
    xpc_object_t xpc_path = xpc_dictionary_get_value(_event, "path");
    if( xpc_path == nullptr || xpc_get_type(xpc_path) != XPC_TYPE_STRING )
        return false;
    const char *path = xpc_string_get_string_ptr(xpc_path);

    xpc_object_t xpc_mode = xpc_dictionary_get_value(_event, "mode");
    if( xpc_mode == nullptr || xpc_get_type(xpc_mode) != XPC_TYPE_INT64 )
        return false;
    const mode_t mode = static_cast<mode_t>(xpc_int64_get_value(xpc_mode));

    const int result = chmod(path, mode);
    if( result == 0 ) {
        send_reply_ok(_event);
    }
    else {
        send_reply_error(_event, errno);
    }
    return true;
}

static bool HandleChTime(xpc_object_t _event) noexcept
{
    const char *operation = xpc_dictionary_get_string(_event, "operation");

    xpc_object_t xpc_path = xpc_dictionary_get_value(_event, "path");
    if( xpc_path == nullptr || xpc_get_type(xpc_path) != XPC_TYPE_STRING )
        return false;
    const char *path = xpc_string_get_string_ptr(xpc_path);

    xpc_object_t xpc_time = xpc_dictionary_get_value(_event, "time");
    if( xpc_time == nullptr || xpc_get_type(xpc_time) != XPC_TYPE_INT64 )
        return false;
    const time_t timesec = static_cast<time_t>(xpc_int64_get_value(xpc_time));

    struct attrlist attrs;
    memset(&attrs, 0, sizeof(attrs));
    attrs.bitmapcount = ATTR_BIT_MAP_COUNT;
    if( strcmp(operation, "chmtime") == 0 )
        attrs.commonattr = ATTR_CMN_MODTIME;
    else if( strcmp(operation, "chctime") == 0 )
        attrs.commonattr = ATTR_CMN_CHGTIME;
    else if( strcmp(operation, "chbtime") == 0 )
        attrs.commonattr = ATTR_CMN_CRTIME;
    else if( strcmp(operation, "chatime") == 0 )
        attrs.commonattr = ATTR_CMN_ACCTIME;

    timespec time = {.tv_sec = timesec, .tv_nsec = 0};

    const int result = setattrlist(path, &attrs, &time, sizeof(time), 0);
    if( result == 0 ) {
        send_reply_ok(_event);
    }
    else {
        send_reply_error(_event, errno);
    }
    return true;
}

static bool HandleRmDir(xpc_object_t _event) noexcept
{
    xpc_object_t xpc_path = xpc_dictionary_get_value(_event, "path");
    if( xpc_path == nullptr || xpc_get_type(xpc_path) != XPC_TYPE_STRING )
        return false;
    const char *path = xpc_string_get_string_ptr(xpc_path);

    const int result = rmdir(path);
    if( result == 0 ) {
        send_reply_ok(_event);
    }
    else {
        send_reply_error(_event, errno);
    }
    return true;
}

static bool HandleUnlink(xpc_object_t _event) noexcept
{
    xpc_object_t xpc_path = xpc_dictionary_get_value(_event, "path");
    if( xpc_path == nullptr || xpc_get_type(xpc_path) != XPC_TYPE_STRING )
        return false;
    const char *path = xpc_string_get_string_ptr(xpc_path);

    const int result = unlink(path);
    if( result == 0 ) {
        send_reply_ok(_event);
    }
    else {
        send_reply_error(_event, errno);
    }
    return true;
}

static bool HandleRename(xpc_object_t _event) noexcept
{
    xpc_object_t xpc_oldpath = xpc_dictionary_get_value(_event, "oldpath");
    if( xpc_oldpath == nullptr || xpc_get_type(xpc_oldpath) != XPC_TYPE_STRING )
        return false;
    const char *oldpath = xpc_string_get_string_ptr(xpc_oldpath);

    xpc_object_t xpc_newpath = xpc_dictionary_get_value(_event, "newpath");
    if( xpc_newpath == nullptr || xpc_get_type(xpc_newpath) != XPC_TYPE_STRING )
        return false;
    const char *newpath = xpc_string_get_string_ptr(xpc_newpath);

    const int result = rename(oldpath, newpath);
    if( result == 0 ) {
        send_reply_ok(_event);
    }
    else {
        send_reply_error(_event, errno);
    }
    return true;
}

static bool HandleReadLink(xpc_object_t _event) noexcept
{
    xpc_object_t xpc_path = xpc_dictionary_get_value(_event, "path");
    if( xpc_path == nullptr || xpc_get_type(xpc_path) != XPC_TYPE_STRING )
        return false;
    const char *path = xpc_string_get_string_ptr(xpc_path);

    char symlink[MAXPATHLEN];
    const ssize_t result = readlink(path, symlink, MAXPATHLEN);
    if( result < 0 ) {
        send_reply_error(_event, errno);
    }
    else {
        symlink[result] = 0;
        xpc_connection_t remote = xpc_dictionary_get_remote_connection(_event);
        xpc_object_t reply = xpc_dictionary_create_reply(_event);
        xpc_dictionary_set_string(reply, "link", symlink);
        xpc_connection_send_message(remote, reply);
        xpc_release(reply);
    }
    return true;
}

static bool HandleSymlink(xpc_object_t _event) noexcept
{
    xpc_object_t xpc_path = xpc_dictionary_get_value(_event, "path");
    if( xpc_path == nullptr || xpc_get_type(xpc_path) != XPC_TYPE_STRING )
        return false;
    const char *path = xpc_string_get_string_ptr(xpc_path);

    xpc_object_t xpc_value = xpc_dictionary_get_value(_event, "value");
    if( xpc_value == nullptr || xpc_get_type(xpc_value) != XPC_TYPE_STRING )
        return false;
    const char *value = xpc_string_get_string_ptr(xpc_value);

    const int result = symlink(value, path);
    if( result == 0 ) {
        send_reply_ok(_event);
    }
    else {
        send_reply_error(_event, errno);
    }
    return true;
}

static bool HandleLink(xpc_object_t _event) noexcept
{
    xpc_object_t xpc_exist = xpc_dictionary_get_value(_event, "exist");
    if( xpc_exist == nullptr || xpc_get_type(xpc_exist) != XPC_TYPE_STRING )
        return false;
    const char *exist = xpc_string_get_string_ptr(xpc_exist);

    xpc_object_t xpc_newnode = xpc_dictionary_get_value(_event, "newnode");
    if( xpc_newnode == nullptr || xpc_get_type(xpc_newnode) != XPC_TYPE_STRING )
        return false;
    const char *newnode = xpc_string_get_string_ptr(xpc_newnode);

    const int result = link(exist, newnode);
    if( result == 0 ) {
        send_reply_ok(_event);
    }
    else {
        send_reply_error(_event, errno);
    }
    return true;
}

static bool HandleKillPG(xpc_object_t _event) noexcept
{
    xpc_object_t xpc_pid = xpc_dictionary_get_value(_event, "pid");
    if( xpc_pid == nullptr || xpc_get_type(xpc_pid) != XPC_TYPE_INT64 )
        return false;
    const pid_t pid = static_cast<pid_t>(xpc_int64_get_value(xpc_pid));

    xpc_object_t xpc_signal = xpc_dictionary_get_value(_event, "signal");
    if( xpc_signal == nullptr || xpc_get_type(xpc_signal) != XPC_TYPE_INT64 )
        return false;
    const int signal = static_cast<int>(xpc_int64_get_value(xpc_signal));

    const int result = killpg(pid, signal);
    if( result == 0 ) {
        send_reply_ok(_event);
    }
    else {
        send_reply_error(_event, errno);
    }
    return true;
}

static bool HandleTrash(xpc_object_t _event) noexcept
{
    const xpc_object_t xpc_path = xpc_dictionary_get_value(_event, "path");
    if( xpc_path == nullptr || xpc_get_type(xpc_path) != XPC_TYPE_STRING )
        return false;
    const char *const path = xpc_string_get_string_ptr(xpc_path);
    assert(path != nullptr);

    const int result = nc::routedio::TrashItemAtPath(path);
    if( result == 0 ) {
        send_reply_ok(_event);
    }
    else {
        send_reply_error(_event, errno);
    }
    return true;
}

static constexpr frozen::unordered_map<frozen::string, bool (*)(xpc_object_t), 23> g_Handlers{
    {"heartbeat", HandleHeartbeat}, //
    {"uninstall", HandleUninstall}, //
    {"exit", HandleExit},           //
    {"open", HandleOpen},           //
    {"stat", HandleStat},           //
    {"lstat", HandleLStat},         //
    {"mkdir", HandleMkDir},         //
    {"chown", HandleChOwn},         //
    {"chflags", HandleChFlags},     //
    {"lchflags", HandleLChFlags},   //
    {"chmod", HandleChMod},         //
    {"chmtime", HandleChTime},      //
    {"chctime", HandleChTime},      //
    {"chbtime", HandleChTime},      //
    {"chatime", HandleChTime},      //
    {"rmdir", HandleRmDir},         //
    {"unlink", HandleUnlink},       //
    {"rename", HandleRename},       //
    {"readlink", HandleReadLink},   //
    {"symlink", HandleSymlink},     //
    {"link", HandleLink},           //
    {"killpg", HandleKillPG},       //
    {"trash", HandleTrash}          //
};

static bool ProcessOperation(const char *_operation, xpc_object_t _event)
{
    // return true if has replied with something

    const auto handler = g_Handlers.find(frozen::string(_operation));
    if( handler != std::end(g_Handlers) )
        return handler->second(_event);

    return false;
}

static void XPC_Peer_Event_Handler(xpc_connection_t _peer, xpc_object_t _event)
{
    syslog_notice("Received event");

    xpc_type_t type = xpc_get_type(_event);

    if( type == XPC_TYPE_DICTIONARY ) {
        ConnectionContext *context = static_cast<ConnectionContext *>(xpc_connection_get_context(_peer));
        if( !context ) {
            send_reply_error(_event, EINVAL);
            return;
        }

        if( xpc_dictionary_get_value(_event, "auth") != nullptr ) {
            if( xpc_dictionary_get_bool(_event, "auth") ) {
                context->authenticated = true;
                send_reply_ok(_event);
            }
            else
                send_reply_error(_event, EINVAL);
            return;
        }

        if( const char *op = xpc_dictionary_get_string(_event, "operation") ) {
            syslog_notice("received operation request: %s", op);

            if( !context->authenticated ) {
                syslog_warning("non-authenticated, dropping");
                send_reply_error(_event, EINVAL);
                return;
            }

            if( ProcessOperation(op, _event) )
                return;
        }

        send_reply_error(_event, EINVAL);
    }
}

static bool AllowConnectionFrom(const char *_bin_path)
{
    if( !_bin_path )
        return false;

    const char *last_sl = strrchr(_bin_path, '/');
    if( !last_sl )
        return false;

    return strcmp(last_sl, "/Nimble Commander") == 0;
}

static bool CheckSignature(const char *_bin_path)
{
    syslog_notice("Checking signature for: %s", _bin_path);

    if( !_bin_path )
        return false;

    OSStatus status = 0;

    CFURLRef url = CFURLCreateFromFileSystemRepresentation(
        nullptr, reinterpret_cast<const UInt8 *>(_bin_path), std::strlen(_bin_path), false);
    if( !url )
        return false;

    // obtain the cert info from the executable
    SecStaticCodeRef ref = nullptr;
    status = SecStaticCodeCreateWithPath(url, kSecCSDefaultFlags, &ref);
    CFRelease(url);
    if( ref == nullptr || status != noErr )
        return false;

    syslog_notice("Got a SecStaticCodeRef");

    // create the requirement to check against
    SecRequirementRef req = nullptr;
    static CFStringRef reqStr = CFStringCreateWithCString(nullptr, g_SignatureRequirement, kCFStringEncodingUTF8);
    status = SecRequirementCreateWithString(reqStr, kSecCSDefaultFlags, &req);
    if( status != noErr || req == nullptr ) {
        CFRelease(ref);
        return false;
    }

    syslog_notice("Built a SecRequirementRef");

    status = SecStaticCodeCheckValidity(ref, kSecCSCheckAllArchitectures, req);

    syslog_notice("Called SecStaticCodeCheckValidity(), verdict: %s", status == noErr ? "valid" : "not valid");

    CFRelease(ref);
    CFRelease(req);

    return status == noErr;
}

static bool CheckHardening(const pid_t _client_pid)
{
    using nc::base::CFPtr;
    const CFPtr<CFMutableDictionaryRef> attr =
        CFPtr<CFMutableDictionaryRef>::adopt(CFDictionaryCreateMutable(nullptr,                        //
                                                                       0,                              //
                                                                       &kCFTypeDictionaryKeyCallBacks, //
                                                                       &kCFTypeDictionaryValueCallBacks));
    const CFPtr<CFNumberRef> pid_number =
        CFPtr<CFNumberRef>::adopt(CFNumberCreate(nullptr, kCFNumberIntType, &_client_pid));
    CFDictionarySetValue(attr.get(), kSecGuestAttributePid, pid_number.get());

    // Get a reference to the running client's code
    SecCodeRef code_ref_input = nullptr;
    if( const OSStatus status =
            SecCodeCopyGuestWithAttributes(nullptr, attr.get(), kSecCSDefaultFlags, &code_ref_input);
        status != errSecSuccess || code_ref_input == nullptr ) {
        return false;
    }
    const CFPtr<SecCodeRef> code_ref = CFPtr<SecCodeRef>::adopt(code_ref_input);

    // Obtain it's dynamic signing information
    CFDictionaryRef csinfo_input = nullptr;
    if( const OSStatus status = SecCodeCopySigningInformation(code_ref.get(), kSecCSDynamicInformation, &csinfo_input);
        status != errSecSuccess || csinfo_input == nullptr ) {
        return false;
    }
    const CFPtr<CFDictionaryRef> csinfo = CFPtr<CFDictionaryRef>::adopt(csinfo_input);

    // Get the signature flags
    CFNumberRef status = static_cast<CFNumberRef>(CFDictionaryGetValue(csinfo.get(), kSecCodeInfoStatus));
    if( status == nullptr || CFGetTypeID(status) != CFNumberGetTypeID() ) {
        return false;
    }
    int flags = 0;
    if( !CFNumberGetValue(status, kCFNumberIntType, &flags) ) {
        return false;
    }

    // Check that either a hardened runtime is enabled or run-time library validation is enabled
    return flags & (kSecCodeSignatureLibraryValidation | kSecCodeSignatureRuntime);
}

static void XPC_Connection_Handler(xpc_connection_t _connection)
{
    const pid_t client_pid = xpc_connection_get_pid(_connection);
    char client_path[1024] = {0};
    proc_pidpath(client_pid, client_path, sizeof(client_path));
    syslog_notice("Got an incoming connection from: %s", client_path);

    if( !AllowConnectionFrom(client_path) || !CheckSignature(client_path) || !CheckHardening(client_pid) ) {
        syslog_warning("Client failed checking, dropping connection.");
        xpc_connection_cancel(_connection);
        return;
    }

    if( __builtin_available(macOS 12.0, *) ) {
        // On MacOS12+ we also ask the OS itself to enforce the code signing requirement per connection
        const int rc = xpc_connection_set_peer_code_signing_requirement(_connection, g_SignatureRequirement);
        if( rc != 0 ) {
            syslog_warning("xpc_connection_set_peer_code_signing_requirement() failed, dropping connection.");
            xpc_connection_cancel(_connection);
            return;
        }
    }

    ConnectionContext *cc = new ConnectionContext;
    xpc_connection_set_context(_connection, cc);
    xpc_connection_set_finalizer_f(_connection, [](void *_value) {
        ConnectionContext *context = static_cast<ConnectionContext *>(_value);
        delete context;
    });
    xpc_connection_set_event_handler(_connection, ^(xpc_object_t event) {
      XPC_Peer_Event_Handler(_connection, event);
    });

    xpc_connection_resume(_connection);
}

int main([[maybe_unused]] int argc, [[maybe_unused]] const char *argv[])
{
    if( getuid() != 0 )
        return EXIT_FAILURE;

    syslog_notice("main() start");

    umask(0); // no brakes!

    xpc_connection_t service = xpc_connection_create_mach_service(
        g_ServiceName, dispatch_get_main_queue(), XPC_CONNECTION_MACH_SERVICE_LISTENER);

    if( !service ) {
        syslog_error("Failed to create service.");
        exit(EXIT_FAILURE);
    }

    syslog_notice("Configuring connection event handler for helper");
    xpc_connection_set_event_handler(service, ^(xpc_object_t connection) {
      XPC_Connection_Handler(static_cast<xpc_connection_t>(connection));
    });

    xpc_connection_resume(service);

    syslog_notice("runs dispatch_main()");
    dispatch_main();

    return EXIT_SUCCESS;
}
