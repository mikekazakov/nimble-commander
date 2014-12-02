//
//  PrivilegedIOHelper.c
//  Files
//
//  Created by Michael G. Kazakov on 29/11/14.
//  Copyright (c) 2014 Michael G. Kazakov. All rights reserved.
//

#include <Security/Security.h>
#include <mach-o/dyld.h>
#include <sys/stat.h>
#include <xpc/xpc.h>
#include <syslog.h>
#include <errno.h>
#include <libproc.h>
#include <stdio.h>

// requires that identifier is right and binary is signed by me
static const char *g_SignatureRequirement = "identifier info.filesmanager.Files and certificate leaf[subject.CN] = \"Mac Developer: Michael Kazakov (4VT72ZQ4R4)\"";

struct ConnectionContext
{
    bool authenticated = false;
};

void send_reply_error(xpc_object_t _from_event, int _error)
{
    xpc_connection_t remote = xpc_dictionary_get_remote_connection(_from_event);
    xpc_object_t reply = xpc_dictionary_create_reply(_from_event);
    xpc_dictionary_set_int64(reply, "error", _error);
    xpc_connection_send_message(remote, reply);
    xpc_release(reply);
}

void send_reply_ok(xpc_object_t _from_event)
{
    xpc_connection_t remote = xpc_dictionary_get_remote_connection(_from_event);
    xpc_object_t reply = xpc_dictionary_create_reply(_from_event);
    xpc_dictionary_set_bool(reply, "ok", true);
    xpc_connection_send_message(remote, reply);
    xpc_release(reply);
}

void send_reply_fd(xpc_object_t _from_event, int _fd)
{
    xpc_connection_t remote = xpc_dictionary_get_remote_connection(_from_event);
    xpc_object_t reply = xpc_dictionary_create_reply(_from_event);
    xpc_dictionary_set_fd(reply, "fd", _fd);
    xpc_connection_send_message(remote, reply);
    xpc_release(reply);
}

// return true if has replied with something
static bool ProcessOperation(const char *_operation,  xpc_object_t _event)
{
    if( strcmp(_operation, "heartbeat") == 0 ) {
        syslog(LOG_NOTICE, "processing heartbeat request");
        send_reply_ok(_event);
    }
    else if( strcmp(_operation, "removeyourself") == 0 ) {
        char path[1024];
        proc_pidpath(getpid(), path, sizeof(path));
        if(unlink(path) == 0)
            send_reply_ok(_event);
        else
            send_reply_error(_event, errno);
    }
    else if( strcmp(_operation, "exit") == 0 ) {
        // no responce here
        syslog(LOG_NOTICE, "goodbye, cruel world!");
        exit(0);
    }
    else if( strcmp(_operation, "open") == 0 ) {
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
    }
    else if( strcmp(_operation, "stat") == 0 ) {
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
    }
    else if( strcmp(_operation, "lstat") == 0 ) {
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
    }
    else if( strcmp(_operation, "mkdir") == 0 ) {
        xpc_object_t xpc_path = xpc_dictionary_get_value(_event, "path");
        if( xpc_path == nullptr || xpc_get_type(xpc_path) != XPC_TYPE_STRING )
            return false;
        const char *path = xpc_string_get_string_ptr(xpc_path);
        
        xpc_object_t xpc_mode = xpc_dictionary_get_value(_event, "mode");
        if( xpc_mode == nullptr || xpc_get_type(xpc_mode) != XPC_TYPE_INT64 )
            return false;
        int mode = (int)xpc_int64_get_value(xpc_mode);
        
        int result = mkdir(path, mode);
        if(result == 0)
            send_reply_ok(_event);
        else
            send_reply_error(_event, errno);
    }
    else if( strcmp(_operation, "chown") == 0 ) {
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
        if(result == 0)
            send_reply_ok(_event);
        else
            send_reply_error(_event, errno);
    }
    else if( strcmp(_operation, "rmdir") == 0 ) {
        xpc_object_t xpc_path = xpc_dictionary_get_value(_event, "path");
        if( xpc_path == nullptr || xpc_get_type(xpc_path) != XPC_TYPE_STRING )
            return false;
        const char *path = xpc_string_get_string_ptr(xpc_path);
        
        int result = rmdir(path);
        if(result == 0)
            send_reply_ok(_event);
        else
            send_reply_error(_event, errno);
    }
    else if( strcmp(_operation, "unlink") == 0 ) {
        xpc_object_t xpc_path = xpc_dictionary_get_value(_event, "path");
        if( xpc_path == nullptr || xpc_get_type(xpc_path) != XPC_TYPE_STRING )
            return false;
        const char *path = xpc_string_get_string_ptr(xpc_path);
        
        int result = unlink(path);
        if(result == 0)
            send_reply_ok(_event);
        else
            send_reply_error(_event, errno);
    }
    else if( strcmp(_operation, "rename") == 0 ) {
        xpc_object_t xpc_oldpath = xpc_dictionary_get_value(_event, "oldpath");
        if( xpc_oldpath == nullptr || xpc_get_type(xpc_oldpath) != XPC_TYPE_STRING )
            return false;
        const char *oldpath = xpc_string_get_string_ptr(xpc_oldpath);

        xpc_object_t xpc_newpath = xpc_dictionary_get_value(_event, "newpath");
        if( xpc_newpath == nullptr || xpc_get_type(xpc_newpath) != XPC_TYPE_STRING )
            return false;
        const char *newpath = xpc_string_get_string_ptr(xpc_newpath);
        
        int result = rename(oldpath, newpath);
        if(result == 0)
            send_reply_ok(_event);
        else
            send_reply_error(_event, errno);
    }
    else if( strcmp(_operation, "readlink") == 0 ) {
        xpc_object_t xpc_path = xpc_dictionary_get_value(_event, "path");
        if( xpc_path == nullptr || xpc_get_type(xpc_path) != XPC_TYPE_STRING )
            return false;
        const char *path = xpc_string_get_string_ptr(xpc_path);
        
        char symlink[MAXPATHLEN];
        ssize_t result = readlink(path, symlink, MAXPATHLEN);
        if(result < 0)
            send_reply_error(_event, errno);
        else {
            symlink[result] = 0;
            xpc_connection_t remote = xpc_dictionary_get_remote_connection(_event);
            xpc_object_t reply = xpc_dictionary_create_reply(_event);
            xpc_dictionary_set_string(reply, "link", symlink);
            xpc_connection_send_message(remote, reply);
            xpc_release(reply);
        }
    }
    else if( strcmp(_operation, "symlink") == 0 ) {
        xpc_object_t xpc_path = xpc_dictionary_get_value(_event, "path");
        if( xpc_path == nullptr || xpc_get_type(xpc_path) != XPC_TYPE_STRING )
            return false;
        const char *path = xpc_string_get_string_ptr(xpc_path);

        xpc_object_t xpc_value = xpc_dictionary_get_value(_event, "value");
        if( xpc_value == nullptr || xpc_get_type(xpc_value) != XPC_TYPE_STRING )
            return false;
        const char *value = xpc_string_get_string_ptr(xpc_value);
        
        int result = symlink(value, path);
        if(result == 0)
            send_reply_ok(_event);
        else
            send_reply_error(_event, errno);
    }
    else
        return false;
    
    return true;
}

static void XPC_Peer_Event_Handler(xpc_connection_t _peer, xpc_object_t _event)
{
   syslog(LOG_NOTICE, "Received event");
    
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
            syslog(LOG_NOTICE, "received operation request: %s", op);

            if(!context->authenticated) {
                syslog(LOG_NOTICE, "non-authenticated, dropping");
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
    
    return strcmp(last_sl, "/Files") == 0;
}

static bool CheckSignature(const char *_bin_path)
{
    syslog(LOG_NOTICE, "Checking signature for: %s", _bin_path);
    
    if(!_bin_path)
        return false;
    
    OSStatus status = 0;
    
    CFURLRef url = CFURLCreateFromFileSystemRepresentation(0, (UInt8*)_bin_path, strlen(_bin_path), false);
    if(!url)
        return false;
    
    // obtain the cert info from the executable
    SecStaticCodeRef ref = NULL;
    status = SecStaticCodeCreateWithPath(url, kSecCSDefaultFlags, &ref);
    CFRelease(url);
    if (ref == NULL || status != noErr)
        return false;
    
    syslog(LOG_NOTICE, "Got a SecStaticCodeRef");
    
    // create the requirement to check against
    SecRequirementRef req = NULL;
    static CFStringRef reqStr = CFStringCreateWithCString(0, g_SignatureRequirement, kCFStringEncodingUTF8);
    status = SecRequirementCreateWithString(reqStr, kSecCSDefaultFlags, &req);
    if(status != noErr || req == NULL) {
        CFRelease(ref);
        return false;
    }
    
    syslog(LOG_NOTICE, "Built a SecRequirementRef");
    
    status = SecStaticCodeCheckValidity(ref, kSecCSCheckAllArchitectures, req);
    
    syslog(LOG_NOTICE, "Called SecStaticCodeCheckValidity(), verdict: %s", status == noErr ? "valid" : "not valid");
    
    CFRelease(ref);
    CFRelease(req);
    
    return status == noErr;
}

static void XPC_Connection_Handler(xpc_connection_t _connection)  {
    pid_t client_pid = xpc_connection_get_pid(_connection);
    char client_path[1024] = {0};
    proc_pidpath(client_pid, client_path, sizeof(client_path));
    syslog(LOG_NOTICE, "Got an incoming connection from: %s", client_path);
    
    if(!AllowConnectionFrom(client_path) || !CheckSignature(client_path)) {
        syslog(LOG_NOTICE, "Client failed checking, dropping connection.");
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
    
    syslog(LOG_NOTICE, "main() start");
    
    umask(0); // no brakes!

    xpc_connection_t service = xpc_connection_create_mach_service("info.filesmanager.Files.PrivilegedIOHelper",
                                                                  dispatch_get_main_queue(),
                                                                  XPC_CONNECTION_MACH_SERVICE_LISTENER);
    
    if (!service) {
        syslog(LOG_NOTICE, "Failed to create service.");
        exit(EXIT_FAILURE);
    }
    
    syslog(LOG_NOTICE, "Configuring connection event handler for helper");
    xpc_connection_set_event_handler(service, ^(xpc_object_t connection) {
        XPC_Connection_Handler((xpc_connection_t)connection);
    });
    
    xpc_connection_resume(service);
    
    syslog(LOG_NOTICE, "runs dispatch_main()");
    dispatch_main();
    
    return EXIT_SUCCESS;
}
