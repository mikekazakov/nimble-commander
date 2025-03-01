// Copyright (C) 2025 Michael Kazakov. Subject to GNU General Public License version 3.
#pragma once

#include <string>
#include <string_view>
#include <memory>
#include <exception>
#include <iosfwd>
#include <optional>
#include <expected>
#include <Base/intrusive_ptr.h>
#include <fmt/format.h>

#ifdef __OBJC__
@class NSError;
#endif

namespace nc {

namespace base {

// This class provides an interface for on-demand generation of messages describing error codes of a particular domain.
class ErrorDescriptionProvider
{
public:
    virtual ~ErrorDescriptionProvider();

    // Provides a short string description of the error code.
    // Not intended to be human-readable.
    // Empty strings are treated as no response.
    virtual std::string Description(int64_t _code) const noexcept;

    // Provides a localized human-readable reason for the failure kind encoded with the specified code.
    // Empty strings are treated as no response.
    virtual std::string LocalizedFailureReason(int64_t _code) const noexcept;
};

} // namespace base

// This class provides a native C++ storage of a structured error description.
// It somewhat mimicks what NSError provides, but it's intended to be passed by value as std::expected<.., Error>.
// The class is lightweight enough to make copies very cheap.
class Error
{
public:
    // Predefined domain for the POSIX error codes.
    static constexpr std::string_view POSIX = "POSIX";

    // Predefined domain for the OSStatus error codes.
    static constexpr std::string_view OSStatus = "OSStatus";

    // Predefined domain for the Mach error codes.
    static constexpr std::string_view Mach = "Mach";

    // Predefined domain for the Cocoa error codes.
    static constexpr std::string_view Cocoa = "Cocoa";

    // Predefined domain for the NSURL error codes.
    static constexpr std::string_view NSURL = "NSURL";

    // Construct an Error with the specified domain and the error code.
    Error(std::string_view _domain, int64_t _code) noexcept;

#ifdef __OBJC__
    // Construct an Error out of the existing NSError.
    explicit Error(NSError *_error) noexcept;
#endif

    // Copy constructor.
    Error(const Error &_other) noexcept;

    // Move constructor/
    Error(Error &&_other) noexcept;

    // Destructor.
    ~Error();

    // Copy assignment.
    Error &operator=(const Error &_rhs) noexcept;

    // Move assignment.
    Error &operator=(Error &&_rhs) noexcept;

    // Returns the domain of this error.
    std::string Domain() const noexcept;

    // Returns the error code of this error.
    int64_t Code() const noexcept;

    // Returns a mechanical representation of the error that includes the domain name, the error code and optionally a
    // verbose non-localized description from the description provider.
    std::string Description() const noexcept;

    // Returns a user-facing failure reason that is app-locale dependent.
    // It is intended for the UI.
    // The reason is first queried from the custom value contained in the error, otherwise if it's not set the
    // description provider is queried.
    std::string LocalizedFailureReason() const noexcept;

    // Set a custom failure reason.
    void LocalizedFailureReason(std::string_view _failure_reason) noexcept;

    // Comparing two Errors for equality.
    // Only the domain and the error code is considered in the comparison.
    friend bool operator==(const Error &_lhs, const Error &_rhs) noexcept;

    // Support output into iostreams for debugging purposes.
    friend std::ostream &operator<<(std::ostream &_os, const Error &_err);

    // Loads a description provider currently set for the specified domain.
    // Returns nullptr if this domain has no associated provider.
    static std::shared_ptr<const base::ErrorDescriptionProvider> DescriptionProvider(std::string_view _domain) noexcept;

    // Stores the description provider for the specified domain.
    // Nullptr is treater as a valid value.
    static void DescriptionProvider(std::string_view _domain,
                                    std::shared_ptr<const base::ErrorDescriptionProvider> _provider) noexcept;

private:
    struct ExternalPayload : public nc::base::intrusive_ref_counter<ExternalPayload> {
        std::string localized_failure_description;
    };

    // Ensures that the external payload exists and prepares for copy-on-write.
    void COW();

    uint64_t m_Domain = -1;
    int64_t m_Code = -1;
    nc::base::intrusive_ptr<ExternalPayload> m_External;
};

// This class wraps Error as a throwable exception.
class ErrorException : public std::exception
{
public:
    // Constructs an expection out of an error.
    ErrorException(const Error &_err) noexcept;

    // Constructs an expection out of an error.
    ErrorException(Error &&_err) noexcept;

    // Destructor.
    ~ErrorException();

    // Provides the description of the underlying Error.
    const char *what() const noexcept override;

    // Provides the underlying Error.
    const Error &error() const noexcept;

private:
    Error m_Error;
    mutable std::optional<std::string> m_What;
};

} // namespace nc

template <>
struct fmt::formatter<nc::Error> : fmt::formatter<std::string> {
    constexpr auto parse(fmt::format_parse_context &_ctx) { return _ctx.begin(); }

    template <typename FormatContext>
    auto format(const nc::Error &_err, FormatContext &_ctx) const
    {
        return fmt::format_to(_ctx.out(), "{}", _err.Description());
    }
};
