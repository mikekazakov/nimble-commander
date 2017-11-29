// Copyright (C) 2014-2017 Michael Kazakov. Subject to GNU General Public License version 3.
#include <Security/Security.h>
#include <mach-o/dyld.h>
#include <sys/stat.h>
#include <xpc/xpc.h>
#include <syslog.h>
#include <errno.h>
#include <libproc.h>
#include <stdio.h>
#include <unordered_map>
#include <string>

using namespace std;

// requires that identifier is right and binary is signed by me
static const char *g_SignatureRequirement =
    "identifier info.filesmanager.Files and "
    "certificate leaf[subject.CN] = \"Developer ID Application: Mikhail Kazakov (AC5SJT236H)\"";

static const char *g_ServiceName = "info.filesmanager.Files.PrivilegedIOHelperV2";

#define syslog_error(...)   syslog(LOG_ERR, __VA_ARGS__)
#define syslog_warning(...) syslog(LOG_WARNING, __VA_ARGS__)
#ifdef DEBUG
    #define syslog_notice(...)  syslog(LOG_NOTICE, __VA_ARGS__)
#else
    #define syslog_notice(...)
#endif

struct ConnectionContext
{
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

static bool HandleExit(xpc_object_t _event) noexcept
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
    int flags = (int)xpc_int64_get_value(xpc_flags);
    
    xpc_object_t xpc_mode = xpc_dictionary_get_value(_event, "mode");
    if( xpc_mode == nullptr || xpc_get_type(xpc_mode) != XPC_TYPE_INT64 )
        return false;
    int mode = (int)xpc_int64_get_value(xpc_mode);
    
    int fd = open(path, flags, mode);
    if(fd >= 0) {
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
    int ret = stat(path, &st);
    if(ret == 0) {
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
    int ret = lstat(path, &st);
    if(ret == 0) {
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
    int mode = (int)xpc_int64_get_value(xpc_mode);
    
    int result = mkdir(path, mode);
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
    uid_t uid = (uid_t)xpc_int64_get_value(xpc_uid);
    
    xpc_object_t xpc_gid = xpc_dictionary_get_value(_event, "gid");
    if( xpc_gid == nullptr || xpc_get_type(xpc_gid) != XPC_TYPE_INT64 )
        return false;
    gid_t gid = (gid_t)xpc_int64_get_value(xpc_gid);
    
    int result = chown(path, uid, gid);
    if(result == 0) {
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
    u_int flags = (u_int)xpc_int64_get_value(xpc_flags);
    
    int result = chflags(path, flags);
    if(result == 0) {
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
    mode_t mode = (mode_t)xpc_int64_get_value(xpc_mode);
    
    int result = chmod(path, mode);
    if(result == 0) {
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
    time_t timesec = (time_t)xpc_int64_get_value(xpc_time);
    
    struct attrlist attrs;
    memset(&attrs, 0, sizeof(attrs));
    attrs.bitmapcount = ATTR_BIT_MAP_COUNT;
    if(strcmp(operation, "chmtime") == 0)      attrs.commonattr = ATTR_CMN_MODTIME;
    else if(strcmp(operation, "chctime") == 0) attrs.commonattr = ATTR_CMN_CHGTIME;
    else if(strcmp(operation, "chbtime") == 0) attrs.commonattr = ATTR_CMN_CRTIME;
    else if(strcmp(operation, "chatime") == 0) attrs.commonattr = ATTR_CMN_ACCTIME;
                    
    timespec time = {timesec, 0};
        
    int result = setattrlist(path, &attrs, &time, sizeof(time), 0);
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
    
    int result = rmdir(path);
    if(result == 0) {
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
    
    int result = unlink(path);
    if(result == 0) {
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
    
    int result = rename(oldpath, newpath);
    if(result == 0) {
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
    ssize_t result = readlink(path, symlink, MAXPATHLEN);
    if(result < 0) {
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
    
    int result = symlink(value, path);
    if(result == 0) {
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
    
    int result = link(exist, newnode);
    if(result == 0) {
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
    pid_t pid = (pid_t)xpc_int64_get_value(xpc_pid);
    
    xpc_object_t xpc_signal = xpc_dictionary_get_value(_event, "signal");
    if( xpc_signal == nullptr || xpc_get_type(xpc_signal) != XPC_TYPE_INT64 )
        return false;
    int signal = (int)xpc_int64_get_value(xpc_signal);
    
    int result = killpg(pid, signal);
    if(result == 0) {
        send_reply_ok(_event);
    }
    else {
        send_reply_error(_event, errno);
    }
    return true;
}

static const unordered_map<string, bool(*)(xpc_object_t)> g_Handlers {
    {"heartbeat",   HandleHeartbeat},
    {"uninstall",   HandleUninstall},
    {"exit",        HandleExit},
    {"open",        HandleOpen},
    {"stat",        HandleStat},
    {"lstat",       HandleLStat},
    {"mkdir",       HandleMkDir},
    {"chown",       HandleChOwn},
    {"chflags",     HandleChFlags},
    {"chmod",       HandleChMod},
    {"chmtime",     HandleChTime},
    {"chctime",     HandleChTime},
    {"chbtime",     HandleChTime},
    {"chatime",     HandleChTime},
    {"rmdir",       HandleRmDir},
    {"unlink",      HandleUnlink},
    {"rename",      HandleRename},
    {"readlink",    HandleReadLink},
    {"symlink",     HandleSymlink},
    {"link",        HandleLink},
    {"killpg",      HandleKillPG}
};

static bool ProcessOperation(const char *_operation,  xpc_object_t _event)
{
    // return true if has replied with something
    
    const auto handler = g_Handlers.find(_operation);
    if( handler != end(g_Handlers) )
        return handler->second(_event);
    
    return false;
}

static void XPC_Peer_Event_Handler(xpc_connection_t _peer, xpc_object_t _event)
{
   syslog_notice("Received event");
    
    xpc_type_t type = xpc_get_type(_event);
    
    if (type == XPC_TYPE_ERROR) {
        if (_event == XPC_ERROR_CONNECTION_INVALID) {
            // The client process on the other end of the connection has either
            // crashed or cancelled the connection. After receiving this error,
            // the connection is in an invalid state, and you do not need to
            // call xpc_connection_cancel(). Just tear down any associated state
            // here.
            
        } else if (_event == XPC_ERROR_TERMINATION_IMMINENT) {
            // Handle per-connection termination cleanup.
        }
//        xpc_release(_peer);
        
    } else if(type == XPC_TYPE_DICTIONARY) {
        ConnectionContext *context = (ConnectionContext*)xpc_connection_get_context(_peer);
        if(!context) {
            send_reply_error(_event, EINVAL);
            return;
        }

        if( xpc_dictionary_get_value(_event, "auth") != nullptr ) {
            if(xpc_dictionary_get_bool(_event, "auth") == true ) {
                context->authenticated = true;
                send_reply_ok(_event);
            }
            else
                send_reply_error(_event, EINVAL);
            return;
        }
        
        if( const char *op = xpc_dictionary_get_string(_event, "operation") ) {
            syslog_notice("received operation request: %s", op);

            if(!context->authenticated) {
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
    if(!_bin_path)
        return false;
    
    const char *last_sl = strrchr(_bin_path, '/');
    if(!last_sl)
        return false;
    
    return strcmp(last_sl, "/Nimble Commander") == 0;
}

static bool CheckSignature(const char *_bin_path)
{
    syslog_notice("Checking signature for: %s", _bin_path);
    
    if(!_bin_path)
        return false;
    
    OSStatus status = 0;
    
    CFURLRef url = CFURLCreateFromFileSystemRepresentation(0,
                                                           (UInt8*)_bin_path,
                                                           strlen(_bin_path),
                                                           false);
    if(!url)
        return false;
    
    // obtain the cert info from the executable
    SecStaticCodeRef ref = NULL;
    status = SecStaticCodeCreateWithPath(url, kSecCSDefaultFlags, &ref);
    CFRelease(url);
    if (ref == NULL || status != noErr)
        return false;
    
    syslog_notice("Got a SecStaticCodeRef");
    
    // create the requirement to check against
    SecRequirementRef req = NULL;
    static CFStringRef reqStr = CFStringCreateWithCString(0,
                                                          g_SignatureRequirement,
                                                          kCFStringEncodingUTF8);
    status = SecRequirementCreateWithString(reqStr, kSecCSDefaultFlags, &req);
    if(status != noErr || req == NULL) {
        CFRelease(ref);
        return false;
    }
    
    syslog_notice("Built a SecRequirementRef");
    
    status = SecStaticCodeCheckValidity(ref, kSecCSCheckAllArchitectures, req);
    
    syslog_notice("Called SecStaticCodeCheckValidity(), verdict: %s",
                  status == noErr ? "valid" : "not valid");
    
    CFRelease(ref);
    CFRelease(req);
    
    return status == noErr;
}

static void XPC_Connection_Handler(xpc_connection_t _connection)  {
    pid_t client_pid = xpc_connection_get_pid(_connection);
    char client_path[1024] = {0};
    proc_pidpath(client_pid, client_path, sizeof(client_path));
    syslog_notice("Got an incoming connection from: %s", client_path);
    
    if(!AllowConnectionFrom(client_path) || !CheckSignature(client_path)) {
        syslog_warning("Client failed checking, dropping connection.");
        xpc_connection_cancel(_connection);
        return;
    }
    
    ConnectionContext *cc = new ConnectionContext;
    xpc_connection_set_context(_connection, cc);
    xpc_connection_set_finalizer_f(_connection, [](void *_value) {
        ConnectionContext *context = (ConnectionContext*) _value;
        delete context;
    });
    xpc_connection_set_event_handler(_connection, ^(xpc_object_t event) {
        XPC_Peer_Event_Handler(_connection, event);
    });
    
    xpc_connection_resume(_connection);
}

int main(int argc, const char *argv[])
{
    if(getuid() != 0)
        return EXIT_FAILURE;
    
    syslog_notice("main() start");
    
    umask(0); // no brakes!

    xpc_connection_t service =
        xpc_connection_create_mach_service(g_ServiceName,
                                           dispatch_get_main_queue(),
                                           XPC_CONNECTION_MACH_SERVICE_LISTENER);
    
    if (!service) {
        syslog_error("Failed to create service.");
        exit(EXIT_FAILURE);
    }
    
    syslog_notice("Configuring connection event handler for helper");
    xpc_connection_set_event_handler(service, ^(xpc_object_t connection) {
        XPC_Connection_Handler((xpc_connection_t)connection);
    });
    
    xpc_connection_resume(service);
    
    syslog_notice("runs dispatch_main()");
    dispatch_main();
    
    return EXIT_SUCCESS;
}
