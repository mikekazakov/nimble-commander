// Copyright (C) 2025 Michael Kazakov. Subject to GNU General Public License version 3.
#include "UnitTests_main.h"
#include <Base/Error.h>
#include <fmt/format.h>
#include <Security/Security.h>
#include <AudioToolbox/AudioToolbox.h>
#include <mach/kern_return.h>

using namespace nc;
using base::ErrorDescriptionProvider;

#define PREFIX "nc::Error "

struct ErrorDescriptionProviderAutoReg {
public:
    ErrorDescriptionProviderAutoReg(std::string_view _domain, std::shared_ptr<const ErrorDescriptionProvider> _provider)
        : m_Domain(_domain)
    {
        m_Previous = Error::DescriptionProvider(_domain);
        Error::DescriptionProvider(_domain, _provider);
    }

    ~ErrorDescriptionProviderAutoReg() { Error::DescriptionProvider(m_Domain, m_Previous); }

private:
    std::string m_Domain;
    std::shared_ptr<const ErrorDescriptionProvider> m_Previous;
};

TEST_CASE(PREFIX "Domain and error code are preserved")
{
    const Error err("some domain", 42);
    CHECK(err.Domain() == "some domain");
    CHECK(err.Code() == 42);
}

TEST_CASE(PREFIX "Description can be synthesized")
{
    const Error err("Hello", 42);
    CHECK(err.Description() == "Error Domain=Hello Code=42");
}

TEST_CASE(PREFIX "Description can query additional information from a provider")
{
    struct Provider : ErrorDescriptionProvider {
        [[nodiscard]] std::string Description(int64_t _code) const noexcept override
        {
            return fmt::format("Description #{}", _code);
        }
    };
    const ErrorDescriptionProviderAutoReg autoreg("Hello", std::make_shared<Provider>());

    const Error err("Hello", 57);
    CHECK(err.Description() == "Error Domain=Hello Code=57 \"Description #57\"");
}

TEST_CASE(PREFIX "Querying failure reason")
{
    struct Provider : ErrorDescriptionProvider {
        [[nodiscard]] std::string LocalizedFailureReason(int64_t _code) const noexcept override
        {
            return fmt::format("Reason#{}", _code);
        }
    };

    const ErrorDescriptionProviderAutoReg autoreg("MyDomain", std::make_shared<Provider>());

    SECTION("From provider")
    {
        const Error err("MyDomain", 42);
        CHECK(err.LocalizedFailureReason() == "Reason#42");
    }
    SECTION("From payload")
    {
        Error err("MyDomain", 42);
        err.LocalizedFailureReason("something bad!");
        CHECK(err.LocalizedFailureReason() == "something bad!");

        // Check COW behaviour
        Error err2 = err;
        CHECK(err.LocalizedFailureReason() == "something bad!");
        CHECK(err2.LocalizedFailureReason() == "something bad!");
        err2.LocalizedFailureReason("wow!");
        CHECK(err.LocalizedFailureReason() == "something bad!");
        CHECK(err2.LocalizedFailureReason() == "wow!");
    }
    SECTION("Fallback to non-localized description")
    {
        struct Provider2 : ErrorDescriptionProvider {
            [[nodiscard]] std::string Description(int64_t _code) const noexcept override
            {
                return fmt::format("!!Reason#{}!!", _code);
            }
        };
        const ErrorDescriptionProviderAutoReg autoreg2("MyDomain", std::make_shared<Provider2>());

        const Error err("MyDomain", 42);
        CHECK(err.LocalizedFailureReason() == "Error Domain=MyDomain Code=42 \"!!Reason#42!!\"");
    }
    SECTION("None available")
    {
        const Error err("Nonsense", 42);
        CHECK(err.LocalizedFailureReason() == "Error Domain=Nonsense Code=42");
    }
}

TEST_CASE(PREFIX "Description providers can be set and unset")
{
    struct Provider : ErrorDescriptionProvider {
        [[nodiscard]] std::string Description(int64_t /*_code*/) const noexcept override { return fmt::format("Hi"); }
    };

    const Error err("Hello", 57);
    CHECK(err.Description() == "Error Domain=Hello Code=57");
    {
        const ErrorDescriptionProviderAutoReg autoreg("Hello", std::make_shared<Provider>());
        CHECK(err.Description() == "Error Domain=Hello Code=57 \"Hi\"");
    }
    CHECK(err.Description() == "Error Domain=Hello Code=57");
}

TEST_CASE(PREFIX "Predefined domains have description providers")
{
    CHECK(Error(Error::POSIX, EINTR).LocalizedFailureReason() == "Interrupted system call");

    CHECK(Error(Error::POSIX, ENFILE).LocalizedFailureReason() == "Too many open files in system");

    CHECK(Error(Error::OSStatus, errSecDiskFull).LocalizedFailureReason() ==
          "The operation couldn’t be completed. (OSStatus error -34.)");

    CHECK(Error(Error::OSStatus, kAudioServicesSystemSoundExceededMaximumDurationError).LocalizedFailureReason() ==
          "The operation couldn’t be completed. (OSStatus error -1502.)");

    CHECK(Error(Error::Mach, KERN_INVALID_ARGUMENT).LocalizedFailureReason() ==
          "The operation couldn’t be completed. (Mach error 4 - (os/kern) invalid argument)");

    CHECK(Error(Error::Mach, kIOReturnVMError).LocalizedFailureReason() ==
          "The operation couldn’t be completed. (Mach error -536870200 - (iokit/common) misc. VM failure)");

    CHECK(Error(Error::Cocoa, NSFileReadCorruptFileError).LocalizedFailureReason() ==
          "The file isn’t in the correct format.");

    CHECK(Error(Error::Cocoa, NSXPCConnectionInterrupted).LocalizedFailureReason() ==
          "Couldn’t communicate with a helper application.");

    CHECK(Error(Error::NSURL, NSURLErrorDNSLookupFailed).LocalizedFailureReason() ==
          "The operation couldn’t be completed. (NSURLErrorDomain error -1006.)");

    CHECK(Error(Error::NSURL, NSURLErrorClientCertificateRequired).LocalizedFailureReason() ==
          "The operation couldn’t be completed. (NSURLErrorDomain error -1206.)");
}

TEST_CASE(PREFIX "Can interface with NSError")
{
    {
        NSError *const ns_err = [NSError errorWithDomain:NSCocoaErrorDomain
                                                    code:NSPropertyListReadUnknownVersionError
                                                userInfo:nil];
        const Error err(ns_err);
        CHECK(err.Domain() == Error::Cocoa);
        CHECK(err.Code() == NSPropertyListReadUnknownVersionError);
        CHECK(err.LocalizedFailureReason() == "The data is in a format that this application doesn’t understand.");
    }
    {
        NSError *const ns_err = [NSError errorWithDomain:NSCocoaErrorDomain
                                                    code:NSPropertyListReadUnknownVersionError
                                                userInfo:@{NSLocalizedFailureReasonErrorKey: @"Hola! 😸"}];
        const Error err(ns_err);
        CHECK(err.Domain() == Error::Cocoa);
        CHECK(err.Code() == NSPropertyListReadUnknownVersionError);
        CHECK(err.LocalizedFailureReason() == "Hola! 😸");
    }
}

TEST_CASE(PREFIX "operator==()")
{
    CHECK(Error(Error::POSIX, EINTR) == Error(Error::POSIX, EINTR));
    CHECK(!(Error(Error::POSIX, EINTR) != Error(Error::POSIX, EINTR)));

    CHECK(!(Error(Error::POSIX, EINTR) == Error(Error::POSIX, EINVAL)));
    CHECK(Error(Error::POSIX, EINTR) != Error(Error::POSIX, EINVAL));

    CHECK(!(Error(Error::Cocoa, EINTR) == Error(Error::POSIX, EINTR)));
    CHECK(Error(Error::Cocoa, EINTR) != Error(Error::POSIX, EINTR));
}

TEST_CASE(PREFIX "ErrorException")
{
    const ErrorException ee(Error{Error::POSIX, EINVAL});
    CHECK(ee.error() == Error{Error::POSIX, EINVAL});
    CHECK(ee.what() == std::string_view("Error Domain=POSIX Code=22"));
}
