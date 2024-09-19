// Copyright (C) 2014-2024 Michael Kazakov. Subject to GNU General Public License version 3.
#include "../include/Utility/KeychainServices.h"
#include <Security/Security.h>
#include <Base/CFPtr.h>

KeychainServices::KeychainServices() = default;

KeychainServices &KeychainServices::Instance()
{
    static auto inst = new KeychainServices;
    return *inst;
}

bool KeychainServices::SetPassword(const std::string &_where, const std::string &_account, const std::string &_password)
{
    using nc::base::CFPtr;
    const CFPtr<CFMutableDictionaryRef> query =
        CFPtr<CFMutableDictionaryRef>::adopt(CFDictionaryCreateMutable(nullptr,                        //
                                                                       0,                              //
                                                                       &kCFTypeDictionaryKeyCallBacks, //
                                                                       &kCFTypeDictionaryValueCallBacks));
    CFDictionarySetValue(query.get(), kSecClass, kSecClassInternetPassword);
    const CFPtr<CFStringRef> server =
        CFPtr<CFStringRef>::adopt(CFStringCreateWithCString(nullptr, _where.c_str(), kCFStringEncodingUTF8));
    CFDictionarySetValue(query.get(), kSecAttrServer, server.get());
    const CFPtr<CFStringRef> account =
        CFPtr<CFStringRef>::adopt(CFStringCreateWithCString(nullptr, _account.c_str(), kCFStringEncodingUTF8));
    CFDictionarySetValue(query.get(), kSecAttrAccount, account.get());
    CFDictionarySetValue(query.get(), kSecMatchLimit, kSecMatchLimitOne);
    CFDictionarySetValue(query.get(), kSecReturnAttributes, kCFBooleanTrue);
    const CFPtr<CFDataRef> value = CFPtr<CFDataRef>::adopt(
        CFDataCreate(nullptr, reinterpret_cast<const UInt8 *>(_password.c_str()), _password.length()));

    CFDictionaryRef existing = nullptr;
    const OSStatus status = SecItemCopyMatching(query.get(), reinterpret_cast<CFTypeRef *>(&existing));

    if( existing ) {
        CFRelease(existing);
    }

    if( status == errSecSuccess ) {
        // update existing item
        const CFPtr<CFMutableDictionaryRef> update = CFPtr<CFMutableDictionaryRef>::adopt(
            CFDictionaryCreateMutable(nullptr, 0, &kCFTypeDictionaryKeyCallBacks, &kCFTypeDictionaryValueCallBacks));
        CFDictionarySetValue(update.get(), kSecValueData, value.get());
        return SecItemUpdate(query.get(), update.get()) == errSecSuccess;
    }
    else if( status == errSecItemNotFound ) {
        // add new item
        CFDictionarySetValue(query.get(), kSecValueData, value.get());
        return SecItemAdd(query.get(), nullptr) == errSecSuccess;
    }
    else {
        return false;
    }
}

bool KeychainServices::GetPassword(const std::string &_where, const std::string &_account, std::string &_password)
{
    using nc::base::CFPtr;
    const CFPtr<CFMutableDictionaryRef> query =
        CFPtr<CFMutableDictionaryRef>::adopt(CFDictionaryCreateMutable(nullptr,                        //
                                                                       0,                              //
                                                                       &kCFTypeDictionaryKeyCallBacks, //
                                                                       &kCFTypeDictionaryValueCallBacks));
    CFDictionarySetValue(query.get(), kSecClass, kSecClassInternetPassword);
    const CFPtr<CFStringRef> server =
        CFPtr<CFStringRef>::adopt(CFStringCreateWithCString(nullptr, _where.c_str(), kCFStringEncodingUTF8));
    CFDictionarySetValue(query.get(), kSecAttrServer, server.get());
    const CFPtr<CFStringRef> account =
        CFPtr<CFStringRef>::adopt(CFStringCreateWithCString(nullptr, _account.c_str(), kCFStringEncodingUTF8));
    CFDictionarySetValue(query.get(), kSecAttrAccount, account.get());
    CFDictionarySetValue(query.get(), kSecReturnData, kCFBooleanTrue);
    CFDictionarySetValue(query.get(), kSecMatchLimit, kSecMatchLimitOne);

    CFDataRef out = nullptr;
    const OSStatus status = SecItemCopyMatching(query.get(), reinterpret_cast<CFTypeRef *>(&out));
    const CFPtr<CFDataRef> result = CFPtr<CFDataRef>::adopt(out);
    if( status == errSecSuccess && result ) {
        _password.assign(reinterpret_cast<const char *>(CFDataGetBytePtr(result.get())), CFDataGetLength(result.get()));
        return true;
    }
    return false;
}

bool KeychainServices::ErasePassword(const std::string &_where, const std::string &_account)
{
    using nc::base::CFPtr;
    const CFPtr<CFMutableDictionaryRef> query =
        CFPtr<CFMutableDictionaryRef>::adopt(CFDictionaryCreateMutable(nullptr,                        //
                                                                       0,                              //
                                                                       &kCFTypeDictionaryKeyCallBacks, //
                                                                       &kCFTypeDictionaryValueCallBacks));
    CFDictionarySetValue(query.get(), kSecClass, kSecClassInternetPassword);
    const CFPtr<CFStringRef> server =
        CFPtr<CFStringRef>::adopt(CFStringCreateWithCString(nullptr, _where.c_str(), kCFStringEncodingUTF8));
    CFDictionarySetValue(query.get(), kSecAttrServer, server.get());
    const CFPtr<CFStringRef> account =
        CFPtr<CFStringRef>::adopt(CFStringCreateWithCString(nullptr, _account.c_str(), kCFStringEncodingUTF8));
    CFDictionarySetValue(query.get(), kSecAttrAccount, account.get());
    return SecItemDelete(query.get()) == errSecSuccess;
}
