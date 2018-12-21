// Copyright (C) 2018 Michael Kazakov. Subject to GNU General Public License version 3.
#pragma once

#include <Habanero/CFString.h>
#include <unordered_map>
#include <string>

namespace nc::bootstrap {
    
class ActivationManagerBase
{
public:
    
    class ExternalLicenseSupport
    {
    public:
        ExternalLicenseSupport(std::string _public_key,
                               std::string _installed_license_path );
        
        bool CheckLicenseValidity( const std::string &_license_data ) const;
        using LicenseInfo = std::unordered_map<std::string, std::string>; 
        LicenseInfo ExtractLicenseInfo( const std::string &_license_data ) const;
        
        bool HasValidInstalledLicense() const;
        LicenseInfo ExtractInfoFromInstalledLicense() const;
        bool InstallNewLicenseWithData( const std::string &_license_data );
        
    private:
        std::string m_PublicKey;
        std::string m_InstalledLicensePath;
    };
      
    class TrialPeriodSupport
    {
    public:
        TrialPeriodSupport(CFStringRef _defaults_trial_expire_date_key);
        virtual ~TrialPeriodSupport() = default;

        bool IsTrialStarted() const;
        int TrialDaysLeft() const;
        void SetupTrialPeriod( double _time_interval_in_seconds );
        void DeleteTrialPeriodInfo();
        
    protected:
        /** 
         * RTFM: absolute time is the time interval since the reference date
         * the reference date (epoch) is 00:00:00 1 January 2001.
         */        
        virtual double SecondsSinceMacEpoch() const;
        
    private:
        CFString m_DefaultsTrialExpireDate;
    };
    
};
    
}
