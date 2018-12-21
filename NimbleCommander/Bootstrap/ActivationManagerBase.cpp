// Copyright (C) 2018 Michael Kazakov. Subject to GNU General Public License version 3.
#include "ActivationManagerBase.h"
#include <Habanero/algo.h>
#include <AquaticPrime/AquaticPrime.h>
#include <Habanero/CFDefaultsCPP.h>
#include <fstream>

namespace nc::bootstrap {

using AMB = ActivationManagerBase; 

static std::optional<std::string> Load(const std::string &_filepath);
static bool Save(const std::string &_filepath, const std::string &_content);
    
AMB::ExternalLicenseSupport::ExternalLicenseSupport( std::string _public_key,
                                                     std::string _installed_license_path):
    m_PublicKey( std::move(_public_key) ),
    m_InstalledLicensePath( std::move(_installed_license_path) )
{
}

bool AMB::ExternalLicenseSupport::
    CheckLicenseValidity( const std::string &_license_file_raw_data ) const
{
    const auto key = CFStringCreateWithUTF8StdString( m_PublicKey );
    if( key == nullptr )
        return false;
    auto release_key = at_scope_end([&]{  CFRelease(key); });
    
    const auto data = CFDataCreate(nullptr,
                                   (const UInt8*)_license_file_raw_data.c_str(),
                                   _license_file_raw_data.length());
    if( data == nullptr )
        return false;
    auto release_data = at_scope_end([&]{  CFRelease(data); });

    APSetKey(key);
    return APVerifyLicenseData(data);
}
    
AMB::ExternalLicenseSupport::LicenseInfo
    AMB::ExternalLicenseSupport::ExtractLicenseInfo( const std::string &_license_data ) const
{
    const auto data = CFDataCreate(nullptr,
                                   (const UInt8*)_license_data.c_str(),
                                   _license_data.length());
    if( data == nullptr )
        return {};
    auto release_data = at_scope_end([&]{  CFRelease(data); });        
    
    const auto key = CFStringCreateWithUTF8StdString( m_PublicKey );
    if( key == nullptr )
        return {};
    auto release_key = at_scope_end([&]{  CFRelease(key); });
    
    APSetKey(key);
    const auto dict = APCreateDictionaryForLicenseData(data);
    if( dict == nullptr )
        return {};
    auto release_dict = at_scope_end([&]{  CFRelease(dict); });    
     
    std::unordered_map<std::string, std::string> result;
    auto block = [](const void *_key, const void *_value, void *_context){
        if( CFGetTypeID(_key) == CFStringGetTypeID() &&
            CFGetTypeID(_value) == CFStringGetTypeID() ) {
            auto &context = *((std::unordered_map<std::string, std::string>*)_context);
            context.insert_or_assign( CFStringGetUTF8StdString( (CFStringRef) _key),
                                      CFStringGetUTF8StdString( (CFStringRef) _value) );    
        }
    };
    CFDictionaryApplyFunction(dict, block, &result);
    return result;
}

bool AMB::ExternalLicenseSupport::HasValidInstalledLicense() const
{
    const auto data = Load(m_InstalledLicensePath);
    if( data == std::nullopt )
        return false;
    
    return CheckLicenseValidity(*data);
}
    
bool AMB::ExternalLicenseSupport::InstallNewLicenseWithData( const std::string &_license_data )
{
    return Save(m_InstalledLicensePath, _license_data);
}
    
AMB::ExternalLicenseSupport::LicenseInfo
    AMB::ExternalLicenseSupport::ExtractInfoFromInstalledLicense() const
{
    const auto data = Load(m_InstalledLicensePath);
    if( data == std::nullopt )
        return {};
    
    return ExtractLicenseInfo(*data);        
}
    
AMB::TrialPeriodSupport::TrialPeriodSupport(CFStringRef _defaults_trial_expire_date_key):
    m_DefaultsTrialExpireDate(_defaults_trial_expire_date_key)
{        
    assert( _defaults_trial_expire_date_key != nullptr );
}

double AMB::TrialPeriodSupport::SecondsSinceMacEpoch() const
{
    return CFAbsoluteTimeGetCurrent();
}
    
bool AMB::TrialPeriodSupport::IsTrialStarted() const
{
    static const double y2016 = 60.*60.*24.*365.*15.;
    return CFDefaultsGetDouble(*m_DefaultsTrialExpireDate) > y2016;
}
    
void AMB::TrialPeriodSupport::SetupTrialPeriod( double _time_interval_in_seconds )
{
    assert( _time_interval_in_seconds > 0. );
    const auto now = SecondsSinceMacEpoch();
    const auto expire_time_point = now + _time_interval_in_seconds;
    CFDefaultsSetDouble( *m_DefaultsTrialExpireDate, expire_time_point );
}
    
void AMB::TrialPeriodSupport::DeleteTrialPeriodInfo()
{
    CFDefaultsRemoveValue( *m_DefaultsTrialExpireDate );        
}

int AMB::TrialPeriodSupport::TrialDaysLeft() const
{
    const auto expire_time_point = CFDefaultsGetDouble(*m_DefaultsTrialExpireDate);
    const auto now = SecondsSinceMacEpoch();
    const auto diff = expire_time_point - now; 
    const auto seconds_in_day = 60. * 60. * 24.;
    const auto days = std::ceil(diff / seconds_in_day);
    if( days < 0. )
        return 0;
    return (int)days;
}
    
static std::optional<std::string> Load(const std::string &_filepath)
{
    std::ifstream in( _filepath, std::ios::in | std::ios::binary );
    if( !in )
        return std::nullopt;        
    
    std::string contents;
    in.seekg( 0, std::ios::end );
    contents.resize( in.tellg() );
    in.seekg( 0, std::ios::beg );
    in.read( &contents[0], contents.size() );
    in.close();
    return contents;
}

static bool Save(const std::string &_filepath, const std::string &_content)
{
    std::ofstream out( _filepath, std::ios::out | std::ios::binary );
    if( !out )
        return false;        
    out << _content;    
    out.close();
    return true;        
}

}
