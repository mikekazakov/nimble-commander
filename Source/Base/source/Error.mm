// Copyright (C) 2025 Michael Kazakov. Subject to GNU General Public License version 3.
#include <Base/Error.h>
#include <Base/UnorderedUtil.h>
#include <Base/spinlock.h>
#include <Base/CFPtr.h>
#include <Base/CFString.h>
#include <CoreFoundation/CoreFoundation.h>
#include <expected>
#include <vector>
#include <iostream>
#include <fmt/format.h>
#include <cassert>

namespace nc {

static_assert(sizeof(Error) == 24);
static_assert(sizeof(std::expected<void, Error>) == 32);
static_assert(sizeof(std::expected<std::string, Error>) == 32);
static_assert(sizeof(std::expected<std::vector<std::string>, Error>) == 32);
static_assert(Error::POSIX.length() <= 8);
static_assert(Error::OSStatus.length() <= 8);
static_assert(Error::Mach.length() <= 8);
static_assert(Error::Cocoa.length() <= 8);
static_assert(Error::NSURL.length() <= 8);

using base::CFPtr;
using base::ErrorDescriptionProvider;

namespace {

// TODO: provide "EINVAL" etc for POSIX domain as a raw Description
class CoreFoundationErrorDescriptionProvider : public ErrorDescriptionProvider
{
public:
    CoreFoundationErrorDescriptionProvider(CFErrorDomain _domain);
    [[nodiscard]] std::string LocalizedFailureReason(int64_t _code) const noexcept override;

private:
    CFErrorDomain m_Domain;
};

CoreFoundationErrorDescriptionProvider::CoreFoundationErrorDescriptionProvider(CFErrorDomain _domain)
    : m_Domain(_domain)
{
}

[[nodiscard]] std::string CoreFoundationErrorDescriptionProvider::LocalizedFailureReason(int64_t _code) const noexcept
{
    const CFPtr<CFErrorRef> cf_error = base::CFPtr<CFErrorRef>::adopt(CFErrorCreate(nullptr, m_Domain, _code, nullptr));
    if( !cf_error )
        return {};

    const CFPtr<CFStringRef> cf_reason = CFPtr<CFStringRef>::adopt(CFErrorCopyFailureReason(cf_error.get()));
    if( cf_reason ) {
        return base::CFStringGetUTF8StdString(cf_reason.get());
    }

    const CFPtr<CFStringRef> cf_description = CFPtr<CFStringRef>::adopt(CFErrorCopyDescription(cf_error.get()));
    if( cf_description ) {
        return base::CFStringGetUTF8StdString(cf_description.get());
    }

    return {};
}

class DomainIndices
{
public:
    static DomainIndices &Instance() noexcept;

    DomainIndices();
    uint64_t Index(std::string_view _domain) noexcept;
    std::string Domain(uint64_t _index) noexcept;

    static constexpr uint64_t POSIX = 0;
    static constexpr uint64_t OSStatus = 1;
    static constexpr uint64_t Mach = 2;
    static constexpr uint64_t Cocoa = 3;
    static constexpr uint64_t NSURL = 4;

private:
    using Map = ankerl::unordered_dense::map<std::string, int64_t, UnorderedStringHashEqual, UnorderedStringHashEqual>;

    uint64_t IndexSlowPath(std::string_view _domain) noexcept;

    Map m_DomainToIndex;
    std::vector<std::string> m_IndexToDomain;
    spinlock m_Lock;
};

DomainIndices &DomainIndices::Instance() noexcept
{
    [[clang::no_destroy]] static DomainIndices inst;
    return inst;
}

DomainIndices::DomainIndices()
{
    auto init = [this](const std::string_view _domain) {
        const uint64_t idx = m_IndexToDomain.size();
        m_DomainToIndex.emplace(_domain, idx);
        m_IndexToDomain.emplace_back(_domain);
    };
    init(Error::POSIX);
    init(Error::OSStatus);
    init(Error::Mach);
    init(Error::Cocoa);
    init(Error::NSURL);
    assert(m_DomainToIndex.at(Error::POSIX) == POSIX);
    assert(m_DomainToIndex.at(Error::OSStatus) == OSStatus);
    assert(m_DomainToIndex.at(Error::Mach) == Mach);
    assert(m_DomainToIndex.at(Error::Cocoa) == Cocoa);
    assert(m_DomainToIndex.at(Error::NSURL) == NSURL);
    assert(m_IndexToDomain.at(POSIX) == Error::POSIX);
    assert(m_IndexToDomain.at(OSStatus) == Error::OSStatus);
    assert(m_IndexToDomain.at(Mach) == Error::Mach);
    assert(m_IndexToDomain.at(Cocoa) == Error::Cocoa);
    assert(m_IndexToDomain.at(NSURL) == Error::NSURL);
}

uint64_t DomainIndices::Index(const std::string_view _domain) noexcept
{
    // Fast path for the built-in indices, clang is shockingly good at optimizing this naive approach.
    if( _domain == Error::POSIX )
        return POSIX;
    if( _domain == Error::OSStatus )
        return OSStatus;
    if( _domain == Error::Mach )
        return Mach;
    if( _domain == Error::Cocoa )
        return Cocoa;
    if( _domain == Error::NSURL )
        return NSURL;

    // General slow path with locking, hashtable lookup and potential insertion of the index
    return IndexSlowPath(_domain);
}

uint64_t DomainIndices::IndexSlowPath(std::string_view _domain) noexcept
{
    const std::lock_guard lock{m_Lock};
    if( auto it = m_DomainToIndex.find(_domain); it != m_DomainToIndex.end() ) {
        return it->second;
    }
    else {
        const uint64_t idx = m_IndexToDomain.size();
        m_DomainToIndex.emplace(_domain, idx);
        m_IndexToDomain.emplace_back(_domain);
        return idx;
    }
}

std::string DomainIndices::Domain(uint64_t _index) noexcept
{
    const std::lock_guard lock{m_Lock};
    if( _index < m_IndexToDomain.size() )
        return m_IndexToDomain[_index];
    return {};
}

class DescriptionProviders
{
public:
    DescriptionProviders();

    static DescriptionProviders &Instance() noexcept;

    std::shared_ptr<const ErrorDescriptionProvider> Get(uint64_t _domain) noexcept;
    void Set(uint64_t _domain, std::shared_ptr<const ErrorDescriptionProvider> _provider) noexcept;

private:
    std::vector<std::shared_ptr<const ErrorDescriptionProvider>> m_Providers;
    spinlock m_Lock;
};

DescriptionProviders::DescriptionProviders()
{
    // Define a set of built-in providers
    auto &idxs = DomainIndices::Instance();

    Set(idxs.Index(Error::POSIX), std::make_shared<CoreFoundationErrorDescriptionProvider>(kCFErrorDomainPOSIX));
    Set(idxs.Index(Error::OSStatus), std::make_shared<CoreFoundationErrorDescriptionProvider>(kCFErrorDomainOSStatus));
    Set(idxs.Index(Error::Mach), std::make_shared<CoreFoundationErrorDescriptionProvider>(kCFErrorDomainMach));
    Set(idxs.Index(Error::Cocoa), std::make_shared<CoreFoundationErrorDescriptionProvider>(kCFErrorDomainCocoa));
    Set(idxs.Index(Error::NSURL), std::make_shared<CoreFoundationErrorDescriptionProvider>(CFSTR("NSURLErrorDomain")));
}

DescriptionProviders &DescriptionProviders::Instance() noexcept
{
    [[clang::no_destroy]] static DescriptionProviders inst;
    return inst;
}

std::shared_ptr<const ErrorDescriptionProvider> DescriptionProviders::Get(uint64_t _domain) noexcept
{
    const std::lock_guard lock{m_Lock};
    if( _domain < m_Providers.size() )
        return m_Providers[_domain];
    return {};
}

void DescriptionProviders::Set(uint64_t _domain, std::shared_ptr<const ErrorDescriptionProvider> _provider) noexcept
{
    const std::lock_guard lock{m_Lock};
    if( _domain >= m_Providers.size() )
        m_Providers.resize(_domain + 1);
    m_Providers[_domain] = std::move(_provider);
}

} // namespace

ErrorDescriptionProvider::~ErrorDescriptionProvider() = default;

std::string ErrorDescriptionProvider::Description([[maybe_unused]] int64_t _code) const noexcept
{
    return {};
}

std::string ErrorDescriptionProvider::LocalizedFailureReason([[maybe_unused]] int64_t _code) const noexcept
{
    return {};
}

Error::Error(std::string_view _domain, int64_t _code) noexcept
    : m_Domain(DomainIndices::Instance().Index(_domain)), m_Code(_code)
{
}

static std::string_view RemapDomain(std::string_view _domain) noexcept
{
    if( _domain == "NSPOSIXErrorDomain" )
        return Error::POSIX;
    if( _domain == "NSOSStatusErrorDomain" )
        return Error::OSStatus;
    if( _domain == "NSMachErrorDomain" )
        return Error::Mach;
    if( _domain == "NSCocoaErrorDomain" )
        return Error::Cocoa;
    if( _domain == "NSURLErrorDomain" )
        return Error::NSURL;
    return _domain;
}

Error::Error(NSError *_error) noexcept
{
    if( _error == nil ) {
        *this = Error(POSIX, EINVAL);
        return;
    }

    NSString *const domain_str = _error.domain;
    const char *const domain_c_str = domain_str.UTF8String;
    if( domain_c_str == nullptr ) {
        *this = Error(POSIX, EINVAL);
        return;
    }

    m_Domain = DomainIndices::Instance().Index(RemapDomain(domain_c_str));
    m_Code = _error.code;
    if( NSDictionary<NSErrorUserInfoKey, id> *const user_info = _error.userInfo ) {
        if( NSString *const ns_reason = [user_info objectForKey:NSLocalizedFailureReasonErrorKey] ) {
            // If there is a custom localized failure reason - retain it in the external payload.
            if( const char *const utf8_reason = ns_reason.UTF8String )
                LocalizedFailureReason(utf8_reason);
        }
    }
}

Error::Error(const Error &) noexcept = default;

Error::Error(Error &&) noexcept = default;

Error::~Error() = default;

Error &Error::operator=(const Error &) noexcept = default;

Error &Error::operator=(Error &&) noexcept = default;

void Error::COW()
{
    if( !m_External ) {
        m_External.reset(new ExternalPayload);
    }
    else if( m_External->use_count() != 1 ) {
        m_External.reset(new ExternalPayload(*m_External));
    }
    assert(m_External);
}

std::string Error::Domain() const noexcept
{
    return DomainIndices::Instance().Domain(m_Domain);
}

int64_t Error::Code() const noexcept
{
    return m_Code;
}

std::string Error::Description() const noexcept
{
    std::string desc;
    if( const std::shared_ptr<const ErrorDescriptionProvider> provider =
            DescriptionProviders::Instance().Get(m_Domain) ) {
        desc = provider->Description(m_Code);
    }

    if( desc.empty() ) {
        return fmt::format("Error Domain={} Code={}", Domain(), Code());
    }
    else {
        return fmt::format("Error Domain={} Code={} \"{}\"", Domain(), Code(), desc);
    }
}

std::string Error::LocalizedFailureReason() const noexcept
{
    if( m_External && !m_External->localized_failure_description.empty() ) {
        return m_External->localized_failure_description;
    }
    if( const std::shared_ptr<const ErrorDescriptionProvider> provider =
            DescriptionProviders::Instance().Get(m_Domain) ) {
        if( auto failure_reason = provider->LocalizedFailureReason(m_Code); !failure_reason.empty() )
            return failure_reason;
    }
    // As a backup return the non-localized description
    return Description();
}

void Error::LocalizedFailureReason(std::string_view _failure_reason) noexcept
{
    COW();
    m_External->localized_failure_description = _failure_reason;
}

std::shared_ptr<const ErrorDescriptionProvider> Error::DescriptionProvider(std::string_view _domain) noexcept
{
    const uint64_t idx = DomainIndices::Instance().Index(_domain);
    return DescriptionProviders::Instance().Get(idx);
}

void Error::DescriptionProvider(std::string_view _domain,
                                std::shared_ptr<const ErrorDescriptionProvider> _provider) noexcept
{
    const uint64_t idx = DomainIndices::Instance().Index(_domain);
    DescriptionProviders::Instance().Set(idx, std::move(_provider));
}

ErrorException::ErrorException(const Error &_err) noexcept : m_Error(_err)
{
}

ErrorException::ErrorException(Error &&_err) noexcept : m_Error(std::move(_err))
{
}

ErrorException::~ErrorException() = default;

const char *ErrorException::what() const noexcept
{
    if( !m_What )
        m_What = m_Error.Description();
    return m_What->c_str();
}

const Error &ErrorException::error() const noexcept
{
    return m_Error;
}

bool operator==(const Error &_lhs, const Error &_rhs) noexcept
{
    return _lhs.m_Domain == _rhs.m_Domain && _lhs.m_Code == _rhs.m_Code;
}

std::ostream &operator<<(std::ostream &_os, const Error &_err)
{
    _os << _err.Description();
    return _os;
}

} // namespace nc
