//
// AquaticPrime.c
// AquaticPrime Core Foundation Implementation
//
// Copyright (c) 2005-2010 Lucas Newman and other contributors
// All rights reserved.
//
// Redistribution and use in source and binary forms, with or without modification,
// are permitted provided that the following conditions are met:
//  -Redistributions of source code must retain the above copyright notice,
//   this list of conditions and the following disclaimer.
//  -Redistributions in binary form must reproduce the above copyright notice,
//   this list of conditions and the following disclaimer in the documentation and/or
//   other materials provided with the distribution.
//  -Neither the name of the Aquatic nor the names of its contributors may be used to 
//   endorse or promote products derived from this software without specific prior written permission.
//
// THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND ANY EXPRESS OR
// IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND
// FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT OWNER OR
// CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL 
// DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, 
// DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER 
// IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT 
// OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.

// This file adapted to use Security.framework instead of deprecated openssl
// Code adapted from the Cocoa implementation by Mathew Waters
// Portions of code from other sources are noted inline

#include "AquaticPrime.h"
#include <Security/Security.h>


static SecKeyRef publicKeyRef;
static __strong CFStringRef hash;
static __strong CFMutableArrayRef blacklist;

static void APSetHash(CFStringRef newHash);
static CFStringRef APPEMKeyCreateFromHexKey(CFStringRef hexKey);
static CFDataRef APCopyDataFromHexString(CFStringRef string);
static CFStringRef APCopyHexStringFromData(CFDataRef data);


Boolean APSetKey(CFStringRef key)
{
    hash = CFSTR("");
    blacklist = CFArrayCreateMutable(kCFAllocatorDefault, 0, &kCFTypeArrayCallBacks);
    
    CFMutableStringRef mutableKey = CFStringCreateMutableCopy(kCFAllocatorDefault, 0, key);
    CFStringRef preparedKey = CFStringCreateMutableCopy(kCFAllocatorDefault, 0, key);
    CFLocaleRef currentLocale = CFLocaleCopyCurrent();
    CFStringLowercase(mutableKey, currentLocale);
    CFRelease(currentLocale);
    
    if (CFStringHasPrefix(mutableKey, CFSTR("0x")) && CFStringGetLength(mutableKey) > 2)
    {
        CFStringDelete(mutableKey, CFRangeMake(0, 2));
    }
    if (CFStringGetLength(mutableKey) == 1024/8*2)
    {
        CFRelease(preparedKey);
        preparedKey = APPEMKeyCreateFromHexKey(mutableKey);
    }
    CFRelease(mutableKey);
    
    
    SecItemImportExportKeyParameters params = {0};
    params.version = SEC_KEY_IMPORT_EXPORT_PARAMS_VERSION;
    params.flags = kSecKeyNoAccessControl;
    SecExternalItemType itemType = kSecItemTypePublicKey;
    SecExternalFormat externalFormat = kSecFormatPEMSequence;
    CFArrayRef tempArray = NULL;
    OSStatus oserr = noErr;
    
    // Set the key as extractable. Looking through the source code in SecImportExportUtils.cpp
    // it looks like this isn't handled, yet it seems to be documented to me. One day the code
    // may catch up, so I'm leaving this here to show the intention.
    CFNumberRef attributeFlags[1];
    uint32 flag0value = CSSM_KEYATTR_EXTRACTABLE;
    CFNumberRef flag0 = CFNumberCreate(kCFAllocatorDefault, kCFNumberIntType, &flag0value);
    attributeFlags[0] = flag0;
    CFArrayRef keyAttributes = CFArrayCreate(kCFAllocatorDefault, (const void **)attributeFlags, 1, &kCFTypeArrayCallBacks);
    CFRelease(flag0);
    params.keyAttributes = keyAttributes;
    
    CFDataRef keyData = CFStringCreateExternalRepresentation(kCFAllocatorDefault, preparedKey, kCFStringEncodingUTF8, 0);
    CFRelease(preparedKey);
    
    oserr = SecItemImport(keyData,
                          NULL,
                          &externalFormat,
                          &itemType,
                          0,
                          &params,
                          NULL,
                          &tempArray);
    CFRelease(keyAttributes);
    CFRelease(keyData);
    
    if (oserr != noErr) {
        CFStringRef errorString = CFStringCreateWithFormat(kCFAllocatorDefault, NULL, CFSTR("Unable to import key. Error %d"), oserr);
        CFShow(errorString);
        CFRelease(errorString);
        return FALSE;
    }
    
    publicKeyRef = (SecKeyRef)CFArrayGetValueAtIndex(tempArray, 0);
    CFRetain(publicKeyRef);
    CFRelease(tempArray);
    
    return TRUE;
}

CFStringRef APPEMKeyCreateFromHexKey(CFStringRef hexKey)
{
    // Convert a raw 1024 bit key to a PEM formatted string that includes the headers
    // -----BEGIN RSA PUBLIC KEY-----
    // (base64 ASN1 encoded data here)
    // -----END RSA PUBLIC KEY-----
    uint8_t raw1[] = {
        0x30, 0x81, 0x9F,                                                    // SEQUENCE length 0x9F
        0x30, 0x0D,                                                            // SEQUENCE length 0x0D
        0x06, 0x09, 0x2A, 0x86, 0x48, 0x86, 0xF7, 0x0D, 0x01, 0x01, 0x01,    // rsaEncryption, PKCS #1
        0x05, 0x00,                                                            // NULL
        0x03, 0x81, 0x8D, 0x00,                                                // BIT STRING, length 0x8D
        0x30, 0x81, 0x89,                                                    // SEQUENCE length 0x89
        0x02, 0x81, 0x81,                                                    // INTEGER length 0x81
        0x00                                                                // MSB = zero to make sure INTEGER is positively signed
    };
    
    uint8_t raw2[] = {
        0x02, 0x03, 0x00, 0x00, 0x03                                        // INTEGER length 3, value = 0x03 (RSA exponent)
    };
    
    
    // Munch through the hex string, taking two characters at a time for each byte
    // to append as the key data
    CFDataRef rawKey = APCopyDataFromHexString(hexKey);
    if (rawKey == NULL) {
        // Failed to import the key (bad hex digit?)
        CFShow(CFSTR("Bad public key?"));
        return NULL;
    }
    
    CFMutableDataRef keyData = CFDataCreateMutable(kCFAllocatorDefault, 0);
    CFDataAppendBytes(keyData, raw1, sizeof(raw1)/sizeof(uint8_t));
    
    const UInt8 *rawKeyBuffer = CFDataGetBytePtr(rawKey);
    CFDataAppendBytes(keyData, rawKeyBuffer, CFDataGetLength(rawKey));
    CFRelease(rawKey);
    
    CFDataAppendBytes(keyData, raw2, sizeof(raw2)/sizeof(uint8_t));
    
    
    // Just need to base64 encode this data now and wrap the string
    // in the BEGIN/END RSA PUBLIC KEY
    CFErrorRef error = NULL;
    SecTransformRef encoder = SecEncodeTransformCreate(kSecBase64Encoding, &error);
    if (error != NULL) {
        CFShow(error);
        if (encoder) {
            CFRelease(encoder);
        }
        if (keyData) {
            CFRelease(keyData);
        }
        return NULL;
    }
    SecTransformSetAttribute(encoder,
                             kSecTransformInputAttributeName,
                             keyData,
                             &error);
    if (error != NULL) {
        CFRelease(encoder);
        if (keyData) {
            CFRelease(keyData);
        }
        CFShow(error);
        return NULL;
    }
    CFDataRef encodedKeyData = SecTransformExecute(encoder, &error);
    const UInt8 *keyDataBuffer = CFDataGetBytePtr(encodedKeyData);
    CFStringRef keyDataString = CFStringCreateWithBytes(kCFAllocatorDefault,
                                                        keyDataBuffer,
                                                        CFDataGetLength(encodedKeyData),
                                                        kCFStringEncodingUTF8,
                                                        false);
    CFRelease(encodedKeyData);
    CFRelease(encoder);
    CFRelease(keyData);
    
    
    CFStringRef beginRSAKey = CFSTR("-----BEGIN RSA PUBLIC KEY-----");
    CFStringRef endRSAKey = CFSTR("-----END RSA PUBLIC KEY-----");
    
    CFStringRef pemKey = CFStringCreateWithFormat(kCFAllocatorDefault,
                                                  NULL,
                                                  CFSTR("%@\n%@\n%@"),
                                                  beginRSAKey,
                                                  keyDataString,
                                                  endRSAKey);
    CFRelease(keyDataString);
    
    return pemKey;
}

CFDataRef APCreateHashFromDictionary(CFDictionaryRef dict)
{
    __block CFErrorRef error = NULL;
    __block SecTransformRef hashFunction = NULL;
    
    void(^cleanup)(void) = ^(void) {
        if (error != NULL) {
            CFShow(error);
            CFRelease(error);
            error = NULL;
        }
        if (hashFunction != NULL) {
            CFRelease(hashFunction);
            hashFunction = NULL;
        }
    };
    
    
    // Get the number of elements
    CFIndex count = CFDictionaryGetCount(dict);
    
    // Load the keys and build up the key array
    CFMutableArrayRef keyArray = CFArrayCreateMutable(kCFAllocatorDefault, count, NULL);
    CFStringRef keys[count];
    CFDictionaryGetKeysAndValues(dict, (const void**)&keys, NULL);
    for (int idx = 0; idx < count; idx++)
    {
        // Skip the signature key
        if (CFStringCompare(keys[idx], CFSTR("Signature"), 0) == kCFCompareEqualTo) {
            continue;
        }
        CFArrayAppendValue(keyArray, keys[idx]);
    }
    
    // Sort the array
    CFStringCompareFlags context = kCFCompareCaseInsensitive;
    CFArraySortValues(keyArray, CFRangeMake(0, count-1), (CFComparatorFunction)CFStringCompare, (void*)context);
    
    
    // Build the data
    CFMutableDataRef dictData = CFDataCreateMutable(kCFAllocatorDefault, 0);
    int keyCount = CFArrayGetCount(keyArray);
    for (int keyIndex = 0; keyIndex < keyCount; keyIndex++)
    {
        CFStringRef key = CFArrayGetValueAtIndex(keyArray, keyIndex);
        CFStringRef value = CFDictionaryGetValue(dict, key);
        
        CFDataRef valueData = CFStringCreateExternalRepresentation(kCFAllocatorDefault,
                                                                   value,
                                                                   kCFStringEncodingUTF8,
                                                                   0);
        const UInt8 *valueBuffer = CFDataGetBytePtr(valueData);
        CFDataAppendBytes(dictData, valueBuffer, CFDataGetLength(valueData));
        CFRelease(valueData);
    }
    
    
    // Hash the data
    hashFunction = SecDigestTransformCreate(kSecDigestSHA1, 0, &error);
    if (error != NULL) {
        CFRelease(dictData);
        cleanup();
        return NULL;
    }
    
    SecTransformSetAttribute(hashFunction,
                             kSecTransformInputAttributeName,
                             dictData,
                             &error);
    CFDataRef hashData = SecTransformExecute(hashFunction, &error);
    CFRelease(dictData);
    
    if (error != NULL) {
        cleanup();
        if (hashData) {
            CFRelease(hashData);
        }
        return NULL;
    }
    
    cleanup();
    
    return hashData;
}

CFStringRef APCopyHash(void)
{
    return CFStringCreateCopy(kCFAllocatorDefault, hash);
}

void APSetHash(CFStringRef newHash)
{
    if (hash != NULL)
        CFRelease(hash);
    hash = CFStringCreateCopy(kCFAllocatorDefault, newHash);
}

// Set the entire blacklist array, removing any existing entries
void APSetBlacklist(CFArrayRef hashArray)
{
    if (blacklist != NULL)
        CFRelease(blacklist);
    blacklist = CFArrayCreateMutableCopy(kCFAllocatorDefault, 0, hashArray);
}

// Add a single entry to the blacklist-- provided because CFArray doesn't have an equivalent
// for NSArray's +arrayWithObjects, which means it may be easier to pass blacklist entries
// one at a time rather than building an array first and passing the whole thing.
void APBlacklistAdd(CFStringRef blacklistEntry)
{
    CFArrayAppendValue(blacklist, blacklistEntry);
}


CFDictionaryRef APCreateDictionaryForLicenseData(CFDataRef data)
{
    __block CFPropertyListRef propertyList = NULL;
    __block CFDataRef hashData = NULL;
    __block CFErrorRef error = NULL;
    __block SecTransformRef verifyFunction = NULL;
    __block CFBooleanRef valid = NULL;
    
    void(^cleanup)(void) = ^(void) {
        if (propertyList != NULL) {
            CFRelease(propertyList);
            propertyList = NULL;
        }
        if (hashData != NULL) {
            CFRelease(hashData);
            hashData = NULL;
        }
        if (error != NULL) {
            CFShow(error);
            CFRelease(error);
            error = NULL;
        }
        if (verifyFunction != NULL) {
            CFRelease(verifyFunction);
            verifyFunction = NULL;
        }
        if (valid != NULL) {
            CFRelease(valid);
            valid = NULL;
        }
    };
    
    if (!publicKeyRef) {
        CFShow(CFSTR("Public key is invalid"));
        return NULL;
    }
    
    
    // Make the property list from the data
    CFStringRef errorString = NULL;
    propertyList = CFPropertyListCreateFromXMLData(kCFAllocatorDefault, data, kCFPropertyListMutableContainers, &errorString);
    if (errorString || CFDictionaryGetTypeID() != CFGetTypeID(propertyList) || !CFPropertyListIsValid(propertyList, kCFPropertyListXMLFormat_v1_0)) {
        if (propertyList)
            CFRelease(propertyList);
        return NULL;
    }
    CFMutableDictionaryRef licenseDictionary = (CFMutableDictionaryRef)propertyList;
    
    
    CFDataRef signature = CFDictionaryGetValue(licenseDictionary, CFSTR("Signature"));
    if (!signature) {
        CFShow(CFSTR("No signature"));
        cleanup();
        return NULL;
    }
    
    
    hashData = APCreateHashFromDictionary(licenseDictionary);
    CFStringRef hashCheck = APCopyHexStringFromData(hashData);
    APSetHash(hashCheck);
    CFRelease(hashCheck);
    
    
    // Check the hash against license blacklist
    if (blacklist && CFArrayContainsValue(blacklist, CFRangeMake(0, CFArrayGetCount(blacklist)), hash)) {
        cleanup();
        return NULL;
    }
    
    
    // Verify the signed hash using the public key, passing the raw hash data as the input
    verifyFunction = SecVerifyTransformCreate(publicKeyRef, signature, &error);
    if (error) {
        cleanup();
        return NULL;
    }
    
    SecTransformSetAttribute(verifyFunction,
                             kSecTransformInputAttributeName,
                             hashData,
                             &error);
    if (error) {
        cleanup();
        return NULL;
    }
    
    SecTransformSetAttribute(verifyFunction,
                             kSecInputIsAttributeName,
                             kSecInputIsRaw,
                             &error);
    if (error) {
        cleanup();
        return NULL;
    }
    
    valid = SecTransformExecute(verifyFunction, &error);
    if (error) {
        cleanup();
        return NULL;
    }
    
    if (valid != kCFBooleanTrue) {
        cleanup();
        return NULL;
    }
    
    CFDictionaryRef resultDict = CFDictionaryCreateCopy(kCFAllocatorDefault, licenseDictionary);
    cleanup();
    return resultDict;
}

CFDictionaryRef APCreateDictionaryForLicenseFile(CFURLRef path)
{
    // Read the XML file
    CFDataRef data;
    SInt32 errorCode;
    Boolean status;
    status = CFURLCreateDataAndPropertiesFromResource(kCFAllocatorDefault, path, &data, NULL, NULL, &errorCode);
    
    if (errorCode || status != true)
        return NULL;
    
    CFDictionaryRef licenseDictionary = APCreateDictionaryForLicenseData(data);
    CFRelease(data);
    return licenseDictionary;
}

Boolean APVerifyLicenseData(CFDataRef data)
{
    CFDictionaryRef licenseDictionary = APCreateDictionaryForLicenseData(data);
    if (licenseDictionary) {
        CFRelease(licenseDictionary);
        return TRUE;
    } else {
        return FALSE;
    }
}

Boolean APVerifyLicenseFile(CFURLRef path)
{
    CFDictionaryRef licenseDictionary = APCreateDictionaryForLicenseFile(path);
    if (licenseDictionary) {
        CFRelease(licenseDictionary);
        return TRUE;
    } else {
        return FALSE;
    }
}


#pragma mark Internal

/* Adapted from StackOverflow: */
/* http://stackoverflow.com/a/12535482 */
static CFDataRef APCopyDataFromHexString(CFStringRef string)
{
    CFIndex length = CFStringGetLength(string);
    CFIndex maxSize =CFStringGetMaximumSizeForEncoding(length, kCFStringEncodingUTF8);
    char *cString = (char *)malloc(maxSize);
    CFStringGetCString(string, cString, maxSize, kCFStringEncodingUTF8);
    
    
    /* allocate the buffer */
    UInt8 * buffer = malloc((strlen(cString) / 2));
    
    char *h = cString; /* this will walk through the hex string */
    UInt8 *b = buffer; /* point inside the buffer */
    
    /* offset into this string is the numeric value */
    char translate[] = "0123456789abcdef";
    
    for ( ; *h; h += 2, ++b) /* go by twos through the hex string */
        *b = ((strchr(translate, *h) - translate) * 16) /* multiply leading digit by 16 */
        + ((strchr(translate, *(h+1)) - translate));
    
    CFDataRef data = CFDataCreate(kCFAllocatorDefault, buffer, (strlen(cString) / 2));
    free(cString);
    free(buffer);
    
    return data;
}


/*
 From Apple open source: SecTrustSettings.c (APSL license)
 Return a (hex)string representation of a CFDataRef.
 */
static CFStringRef APCopyHexStringFromData(CFDataRef data)
{
    CFIndex ix, length;
    const UInt8 *bytes;
    CFMutableStringRef string;
    
    if (data) {
        length = CFDataGetLength(data);
        bytes = CFDataGetBytePtr(data);
    } else {
        length = 0;
        bytes = NULL;
    }
    string = CFStringCreateMutable(kCFAllocatorDefault, length * 2);
    for (ix = 0; ix < length; ++ix)
        CFStringAppendFormat(string, NULL, CFSTR("%02X"), bytes[ix]);
    
    return string;
}

